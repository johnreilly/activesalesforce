=begin
  ActiveSalesforce
  Copyright (c) 2006 Doug Chasman

  Permission is hereby granted, free of charge, to any person obtaining a copy
  of this software and associated documentation files (the "Software"), to deal
  in the Software without restriction, including without limitation the rights
  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
  copies of the Software, and to permit persons to whom the Software is
  furnished to do so, subject to the following conditions:

  The above copyright notice and this permission notice shall be included in
  all copies or substantial portions of the Software.

  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
  SOFTWARE.
=end

require 'rubygems'
require_gem 'rails', ">= 1.0.0"

require 'thread'

require File.dirname(__FILE__) + '/salesforce_login'
require File.dirname(__FILE__) + '/column_definition'

class ResultArray < Array
  attr_reader :actual_size
  
  def initialize(actual_size)
    @actual_size = actual_size
  end
end

module ActiveRecord    
  class Base   
    @@cache = {}
    
    # Establishes a connection to the database that's used by all Active Record objects.
    def self.salesforce_connection(config) # :nodoc:
      puts "Using Salesforce connection!"
      
      config = config.symbolize_keys
      
      url = config[:url].to_s
      username = config[:username].to_s
      password = config[:password].to_s
      
      connection = @@cache["#{url}.#{username}.#{password}"]
      
      if not connection
        connection = SalesforceLogin.new(url, username, password).proxy 
        @@cache["#{url}.#{username}.#{password}"] = connection
        puts "Created new connection for [#{url}, #{username}]"
      end
      
      ConnectionAdapters::SalesforceAdapter.new(connection, logger, [url, username, password], config)
    end
  end
  
  
  module ConnectionAdapters
    class SalesforceError < RuntimeError
      attr :fault
      
      def initialize(message, fault)
        super message
        
        @fault = fault
        
        puts "\nSalesforceError:\n   message='#{message}'\n   fault='#{fault}'\n\n"
      end
    end
    
    class SalesforceAdapter < AbstractAdapter
      COLUMN_NAME_REGEX = /@C_(\w+)/
      COLUMN_VALUE_REGEX = /@V_'(([^']|\\')*)'/
      
      include StringHelper
      
      attr_accessor :batch_size
      
      def initialize(connection, logger, connection_options, config)
        super(connection, logger)
        
        @connection_options, @config = connection_options, config
        
        @columns_map = {}
        @columns_name_map = {}
        
        @relationships_map = {}
      end
      
      
      def adapter_name #:nodoc:
        'Salesforce'
      end
      
      
      def supports_migrations? #:nodoc:
        false
      end
      
      
      # QUOTING ==================================================
      
      def quote(value, column = nil)
        case value
          when NilClass              then quoted_value = "'NULL'"
          when TrueClass             then quoted_value = "'TRUE'"
          when FalseClass            then quoted_value = "'FALSE'"
          else                       quoted_value = super(value, column)
        end      
        
        "@V_#{quoted_value}"
      end
      
      
      def quote_column_name(name) #:nodoc:
        # Mark the column name to make it easier to find later
        "@C_#{name}"
      end
      
      # CONNECTION MANAGEMENT ====================================
      
      def active?
        true
      end
      
      
      def reconnect!
        connect
      end
      
      
      # DATABASE STATEMENTS ======================================
      
      def select_all(sql, name = nil) #:nodoc:
        table_name = table_name_from_sql(sql)
        entity_name = entity_name_from_table(table_name)
        column_names = api_column_names(table_name)
        
        soql = sql.sub(/SELECT \* FROM \w+ /, "SELECT #{column_names.join(', ')} FROM #{table_name} ")
        
        # Look for a LIMIT clause
        soql.sub!(/LIMIT 1/, "")
        
        # Look for an OFFSET clause
        soql.sub!(/\d+ OFFSET \d+/, "")
        
        # Fixup column references to use api names
        columns = columns_map(table_name)
        while soql =~ COLUMN_NAME_REGEX
          column = columns[$~[1]]
          soql = $~.pre_match + column.api_name + $~.post_match
        end
        
        # Remove column value prefix
        soql.gsub!(/@V_/, "")
        
        log(soql, name)
        
        @connection.batch_size = @batch_size if @batch_size
        @batch_size = nil
        
        queryResult = get_result(@connection.query(:queryString => soql), :query)
        records = queryResult.records
        
        result = ResultArray.new(queryResult[:size].to_i)
        return result unless records
        
        records = [ records ] unless records.is_a?(Array)
        
        records.each do |record|
          row = {}
          
          record.each do |name, value| 
            name = column_nameize(name.to_s)
            
            # Replace nil element with nil
            value = nil if value.respond_to?(:xmlattr_nil) and value.xmlattr_nil
            
            # Ids are returned in an array with 2 duplicate entries...
            value = value[0] if name == "id"
            
            row[name] = value
          end  
          
          result << row        
        end
        
        result
      end
      
      
      def select_one(sql, name = nil) #:nodoc:
        self.batch_size = 1
        
        # Check for SELECT COUNT(*) FROM query
        matchCount = sql.match(/SELECT COUNT\(\*\) FROM (\w+)/)       
        if matchCount
          sql = "SELECT id FROM #{matchCount[1].singularize} #{matchCount.post_match}"
        end
        
        result = select_all(sql, name)
        
        if matchCount
          { :count => result.actual_size }
        else
          result.nil? ? nil : result.first
        end
      end
      
      
      def insert(sql, name = nil, pk = nil, id_value = nil, sequence_name = nil)
        log(sql, name)
        
        # Convert sql to sobject
        table_name = sql.match(/INSERT INTO (\w+) /)[1].singularize
        entity_name = entity_name_from_table(table_name)
        columns = columns_map(table_name)
        
        # Extract array of column names
        names = extract_columns(sql)
        
        # Extract arrays of values
        values = extract_values(sql)

        pp names
        pp values
                
        fields = {}
        names.each_with_index do | name, n | 
          value = values[n]
          column = columns[name]
          
          fields[column.api_name] = value if not column.readonly and value != "NULL"
        end
        
        sobject = create_sobject(entity_name, nil, fields)
        
        check_result(get_result(@connection.create(:sObjects => sobject), :create))[0][:id]
      end      
      
      
      def update(sql, name = nil) #:nodoc:
        log(sql, name)
        
        # Convert sql to sobject
        table_name = sql.match(/UPDATE (\w+) /)[1].singularize
        entity_name = entity_name_from_table(table_name)
        columns = columns_map(table_name)
        
        names = extract_columns(sql)
        values = extract_values(sql)

        fields = {}
        names.each_with_index do | name, n | 
          column = columns[name]
          value = values[n]
          fields[column.api_name] = value if not column.readonly and value != "NULL"
        end

        id = sql.match(/WHERE id = @V_'(\w+)'/)[1]
        
        sobject = create_sobject(entity_name, id, fields)
        
        check_result(get_result(@connection.update(:sObjects => sobject), :update))
      end
      
      
      def delete(sql, name = nil) 
        log(sql, name)
        
        # Extract the ids
        ids = extract_values(sql)
        
        ids_element = []        
        ids.each { |id| ids_element << :ids << id }
        
        check_result(get_result(@connection.delete(ids_element), :delete))
      end
      
      
      def get_result(response, method)
        responseName = (method.to_s + "Response").to_sym
        finalResponse = response[responseName]
        
        raise SalesforceError.new(response[:fault][:faultstring], response.fault) unless finalResponse
        
        result = finalResponse[:result]
      end       
      
      
      def check_result(result)
        result = [ result ] unless result.is_a?(Array)
        
        result.each do |r|
            raise SalesforceError.new(r[:errors], r[:errors][:message]) unless r[:success] == "true"
        end
        
        result
      end
      
      
      def columns(table_name, name = nil)
        entity_name = entity_name_from_table(table_name)
        
        cached_columns = @columns_map[entity_name]
        return cached_columns if cached_columns
        
        cached_columns = []
        @columns_map[entity_name] = cached_columns
        
        cached_relationships = []
        @relationships_map[entity_name] = cached_relationships
        
        metadata = get_result(@connection.describeSObject(:sObjectType => entity_name), :describeSObject)
        
        metadata.fields.each do |field| 
          column = SalesforceColumn.new(field) 
          cached_columns << column
          
          cached_relationships << SalesforceRelationship.new(field) if field[:type] =~ /reference/i
        end
        
        if metadata.childRelationships
          metadata.childRelationships.each do |relationship|
            
            if relationship[:childSObject].casecmp(entity_name) == 0
              r = SalesforceRelationship.new(relationship)
              cached_relationships << r
            end
          end
        end
        
        configure_active_record entity_name
        
        cached_columns
      end
      
      
      def configure_active_record(entity_name)
        klass = entity_name.constantize
        klass.table_name = entity_name
        klass.pluralize_table_names = false
        klass.set_inheritance_column nil
        klass.lock_optimistically = false
        klass.record_timestamps = false
        klass.default_timezone = :utc 
        
        # Create relationships for any reference field
        @relationships_map[entity_name].each do |relationship|
          referenceName = relationship.name
          unless self.respond_to? referenceName.to_sym or relationship.reference_to == "Profile"
            reference_to = relationship.reference_to
            
            begin
              reference_to.constantize
            rescue NameError => e
              # Automatically create a least a stub for the referenced entity
              referenced_klass = klass.class_eval("::#{reference_to} = Class.new(ActiveRecord::Base)")
              puts "Created ActiveRecord stub for the referenced entity '#{reference_to}'"
            end
            
            one_to_many = relationship.one_to_many
            foreign_key = relationship.foreign_key
            
            if one_to_many
              klass.has_many referenceName.to_sym, :class_name => reference_to, :foreign_key => foreign_key, :dependent => false
            else
              klass.belongs_to referenceName.to_sym, :class_name => reference_to, :foreign_key => foreign_key, :dependent => false
            end
            
            puts "Created one-to-#{one_to_many ? 'many' : 'one' } relationship '#{referenceName}' from #{entity_name} to #{relationship.reference_to} using #{foreign_key}"
            
          end
        end
        
      end
      
      
      def relationships(table_name)
        entity_name = entity_name_from_table(table_name)
        
        cached_relationships = @relationships_map[entity_name]
        
        unless cached_relationships
          # This will load column and relationship metadata        
          columns(table_name)
        end
        
        @relationships_map[entity_name]
      end
      
      
      def columns_map(table_name, name = nil)
        entity_name = entity_name_from_table(table_name)
        
        columns_map = @columns_name_map[entity_name]
        unless columns_map 
          columns_map = {}
          @columns_name_map[entity_name] = columns_map
          
          columns(entity_name).each { |column| columns_map[column.name] = column }
        end
        
        columns_map
      end
      
      
      def entity_name_from_table(table_name)
        return table_name.singularize.camelize
      end
      
      
      def create_sobject(entity_name, id, fields)
        sobj = [ 'type { :xmlns => "urn:sobject.partner.soap.sforce.com" }', entity_name ]
        sobj << 'Id { :xmlns => "urn:sobject.partner.soap.sforce.com" }' << id if id    
        
        # now add any changed fields
        fieldValues = {}
        fields.each do | name, value |
          sobj << name.to_sym << value if value
        end
        
        sobj
      end
      
      
      def table_name_from_sql(sql)
        sql.match(/FROM (\w+) /)[1].singularize
      end
      
      
      def column_names(table_name)
        columns(table_name).map { |column| column.name }
      end
      
      
      def api_column_names(table_name)
        columns(table_name).map { |column| column.api_name }
      end
      
      
      def extract_columns(sql)
        sql.scan(COLUMN_NAME_REGEX).flatten
      end
      
      
      def extract_values(sql)
        sql.scan(COLUMN_VALUE_REGEX).map { |v| v[0] }
      end
      
    end
    
  end
end
