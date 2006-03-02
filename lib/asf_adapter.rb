=begin
  ActiveSalesforce
  Copyright 2006 Doug Chasman
 
  Licensed under the Apache License, Version 2.0 (the "License");
  you may not use this file except in compliance with the License.
  You may obtain a copy of the License at
 
     http://www.apache.org/licenses/LICENSE-2.0
 
  Unless required by applicable law or agreed to in writing, software
  distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions and
  limitations under the License.
=end

require 'rubygems'
require_gem 'rails', ">= 1.0.0"
  
require 'thread'  
require 'benchmark'

require File.dirname(__FILE__) + '/rforce'
require File.dirname(__FILE__) + '/column_definition'
require File.dirname(__FILE__) + '/relationship_definition'
require File.dirname(__FILE__) + '/boxcar_command'
require File.dirname(__FILE__) + '/entity_definition'
require File.dirname(__FILE__) + '/asf_active_record'
require File.dirname(__FILE__) + '/id_resolver'
require File.dirname(__FILE__) + '/sid_authentication_filter'


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
    def self.activesalesforce_connection(config) # :nodoc:
      logger.debug("\nUsing ActiveSalesforce connection\n")
      
      # Default to production system using 7.0 API
      url = config[:url]
      url = "https://www.salesforce.com/services/Soap/u/7.0" unless url

      sid = config[:sid]  
      binding = config[:binding] if config[:binding]
      
      if binding
        logger.debug("   via provided binding #{binding}\n")
      end
      
      if sid
        binding = @@cache["sid=#{sid}"] unless binding
        
        unless binding
          logger.debug("Establishing new connection for [sid='#{sid}']")
          
          binding = RForce::Binding.new(url, sid)
          @@cache["sid=#{sid}"] = binding
          
          logger.debug("Created new connection for [sid='#{sid}']")
        end
        
        ConnectionAdapters::SalesforceAdapter.new(binding, logger, [url, sid], config)
      else
        # Check to insure that the second to last path component is a 'u' for Partner API
        raise ConnectionAdapters::SalesforceError.new(logger, "Invalid salesforce server url '#{url}', must be a valid Parter API URL") unless url.match(/\/u\//i)
        
        username = config[:username]
        password = config[:password]
        
        binding = @@cache["#{url}.#{username}.#{password}"] unless binding
        
        unless binding
          logger.debug("Establishing new connection for ['#{url}', '#{username}']")
          
          seconds = Benchmark.realtime {
            binding = RForce::Binding.new(url, sid)
            binding.login(username, password).result
            
            @@cache["#{url}.#{username}.#{password}"] = binding
          }
          
          logger.debug("Created new connection for ['#{url}', '#{username}'] in #{seconds} seconds")
        end
        
        ConnectionAdapters::SalesforceAdapter.new(binding, logger, [url, username, password, sid], config)
      end
    end
  end

  
  module ConnectionAdapters
    class SalesforceError < RuntimeError
      attr :fault
      
      def initialize(logger, message, fault = nil)
        super message
        
        @fault = fault
        
        logger.debug("\nSalesforceError:\n   message='#{message}'\n   fault='#{fault}'\n\n")
      end
    end
    
    
    class SalesforceAdapter < AbstractAdapter
      include StringHelper
 
      MAX_BOXCAR_SIZE = 200
      
      attr_accessor :batch_size
      attr_reader :entity_def_map, :keyprefix_to_entity_def_map, :config
      
      def initialize(connection, logger, connection_options, config)
        super(connection, logger)
        
        @connection_options, @config = connection_options, config
        
        @entity_def_map = {}
        @keyprefix_to_entity_def_map = {}
        
        @command_boxcar = []
        @class_to_entity_map = {}
      end
      
      
      def set_class_for_entity(klass, entity_name)
        @logger.debug("Setting @class_to_entity_map['#{entity_name.upcase}'] = #{klass}")
        @class_to_entity_map[entity_name.upcase] = klass
      end
      
      
      def binding
        @connection
      end
      
      
      def adapter_name #:nodoc:
        'ActiveSalesforce'
      end
      
      
      def supports_migrations? #:nodoc:
        false
      end
      
      
      # QUOTING ==================================================
      
      def quote(value, column = nil)
        case value
        when NilClass              then quoted_value = "NULL"
        when TrueClass             then quoted_value = "TRUE"
        when FalseClass            then quoted_value = "FALSE"
        else                       quoted_value = super(value, column)
        end      
        
        quoted_value
      end
      
      # CONNECTION MANAGEMENT ====================================
      
      def active?
        true
      end
      
      
      def reconnect!
        connect
      end
      
      
      # TRANSACTIOn SUPPORT (Boxcarring really because the salesforce.com api does not support transactions)
      
      # Begins the transaction (and turns off auto-committing).
      def begin_db_transaction()    
        log('Opening boxcar', 'begin_db_transaction()')
        @command_boxcar = []
      end
      
      
      def send_commands(commands)
        # Send the boxcar'ed command set
        verb = commands[0].verb
        
        args = []
        commands.each do |command| 
          command.args.each { |arg| args << arg }
        end
        
        puts "  send_commands(:#{verb}, [#{args.join(', ')}])"
        
        response = @connection.send(verb, args)
        
        result = get_result(response, verb)
        
        result = [ result ] unless result.is_a?(Array)
        errors = []
        result.each_with_index do |r, n|
          success = r[:success] == "true"
          
          # Give each command a chance to process its own result
          command = commands[n]
          command.after_execute(r)
          
          # Handle the set of failures
          errors << r[:errors] unless r[:success] == "true"
        end
        
        unless errors.empty?
          message = errors.join("\n")
          fault = (errors.map { |error| error[:message] }).join("\n")
          SalesforceError.new(@logger, message, fault) 
        end
        
        result
      end
      
      
      # Commits the transaction (and turns on auto-committing).
      def commit_db_transaction()   
        log("Committing boxcar with #{@command_boxcar.length} commands", 'commit_db_transaction()')
        
        previous_command = nil
        commands = []
        @command_boxcar.each do |command|
          if commands.length >= MAX_BOXCAR_SIZE or (previous_command and (command.verb != previous_command.verb))
            send_commands(commands)
            commands = []
          else
            commands << command
          end
          
          previous_command = command
        end
        
        # Finish off the partial boxcar
        send_commands(commands) unless commands.empty?
        
      end
      
      # Rolls back the transaction (and turns on auto-committing). Must be
      # done if the transaction block raises an exception or returns false.
      def rollback_db_transaction() 
        log('Rolling back boxcar', 'rollback_db_transaction()')
        @command_boxcar = []
      end
      
      
      # DATABASE STATEMENTS ======================================
      
      def select_all(sql, name = nil) #:nodoc:
        log(sql, name) {
          # Check for SELECT COUNT(*) FROM query
          selectCountMatch = sql.match(/SELECT\s+COUNT\(\*\)\s+FROM/i)       
          if selectCountMatch
            soql = "SELECT id FROM#{selectCountMatch.post_match}"
          end
          
          raw_table_name = sql.match(/FROM (\w+)/i)[1]
          table_name = raw_table_name.singularize
          entity_name = entity_name_from_table(table_name)
          entity_def = get_entity_def(entity_name)
          
          column_names = api_column_names(table_name)
          
          # Always (unless COUNT*)'ing) select all columns (required for the AR attributes mechanism to work correctly
          soql = sql.sub(/SELECT .+ FROM/i, "SELECT #{column_names.join(', ')} FROM") unless selectCountMatch
          
          soql.sub!(/\s+FROM\s+\w+/i, " FROM #{entity_def.api_name}")
          
          # Look for a LIMIT clause
          soql.sub!(/LIMIT\s+1/i, "")
          
          # Look for an OFFSET clause
          soql.sub!(/\d+\s+OFFSET\s+\d+/i, "")
          
          # Fixup column references to use api names
          columns = columns_map(table_name)
          soql.gsub!(/((?:\w+\.)?\w+)(?=\s*(?:=|!=|<|>|<=|>=)\s*(?:'[^']*'|NULL|TRUE|FALSE))/mi) do |column_name| 
            # strip away any table alias
            column_name.sub!(/\w+\./, '')
            
            column = columns[column_name]
            raise SalesforceError.new(@logger, "Column not found for #{column_name}!") unless column
            
            column.api_name
          end
          
          # Update table name references
          soql.sub!(/#{raw_table_name}\./i, "#{entity_def.api_name}.")
          
          @connection.batch_size = @batch_size if @batch_size
          @batch_size = nil
          
          queryResult = get_result(@connection.query(:queryString => soql), :query)
          records = queryResult[:records]
          
          result = ResultArray.new(queryResult[:size].to_i)
          return result unless records
          
          records = [ records ] unless records.is_a?(Array)
          
          records.each do |record|
            row = {}
            
            record.each do |name, value| 
              if name != :type
                # Ids may be returned in an array with 2 duplicate entries...
                value = value[0] if name == :Id && value.is_a?(Array)
                
                column = entity_def.api_name_to_column[name.to_s]
                attribute_name = column.name
                
                if column.type == :boolean
                  row[attribute_name] = (value.casecmp("true") == 0)
                else
                  row[attribute_name] = value
                end
              end
            end  
            
            result << row   
          end
          
          if selectCountMatch
            [{ :count => result.actual_size }]
          else
            result
          end
        }
      end
      
      
      def select_one(sql, name = nil) #:nodoc:
        self.batch_size = 1
        
        result = select_all(sql, name)
        
        result.nil? ? nil : result.first
      end
      
      
      def insert(sql, name = nil, pk = nil, id_value = nil, sequence_name = nil)
        log(sql, name) {
          # Convert sql to sobject
          table_name = sql.match(/INSERT\s+INTO\s+(\w+)\s+/i)[1].singularize
          entity_name = entity_name_from_table(table_name)
          columns = columns_map(table_name)
          
          # Extract array of column names
          names = sql.match(/\((.+)\)\s+VALUES/i)[1].scan(/\w+/i)
          
          # Extract arrays of values
          values = sql.match(/VALUES\s*\((.+)\)/i)[1]
          values = values.scan(/(((NULL))|((TRUE))|((FALSE))|'(([^']|'')*)'),*/mi)
          
          values.map! { |v| v[7] }
          
          fields = get_fields(columns, names, values, :createable)
          
          sobject = create_sobject(entity_name, nil, fields)
          
          # Track the id to be able to update it when the create() is actually executed
          id = String.new
          @command_boxcar << ActiveSalesforce::BoxcarCommand::Insert.new(self, sobject, id)
          
          id
        }
      end      
      
      
      def update(sql, name = nil) #:nodoc:
        log(sql, name) {
          # Convert sql to sobject
          table_name = sql.match(/UPDATE\s+(\w+)\s+/i)[1].singularize
          entity_name = entity_name_from_table(table_name)
          columns = columns_map(table_name)
          
          match = sql.match(/SET\s+(.+)\s+WHERE/mi)[1]
          names = match.scan(/(\w+)\s*=\s*('|NULL|TRUE|FALSE)/i)
          names.map! { |v| v[0] }
          
          values = match.scan(/=\s*(((NULL))|((TRUE))|((FALSE))|'(([^']|'')*)'),*/mi)
          values.map! { |v| v[7] }
          
          fields = get_fields(columns, names, values, :updateable)
          
          id = sql.match(/WHERE\s+id\s*=\s*'(\w+)'/i)[1]
          
          sobject = create_sobject(entity_name, id, fields)
          
          @command_boxcar << ActiveSalesforce::BoxcarCommand::Update.new(self, sobject)
        }
      end
      
      
      def delete(sql, name = nil) 
        log(sql, name) {
          # Extract the id
          match = sql.match(/WHERE\s+id\s*=\s*'(\w+)'/mi)
          
          if match 
            ids = [ match[1] ]
          else
            # Check for the form id IN ('x', 'y')
            match = sql.match(/WHERE\s+id\s+IN\s*\((.+)\)/mi)[1]
            ids = match.scan(/\w+/)
          end
          
          ids_element = []        
          ids.each { |id| ids_element << :ids << id }
          
          @command_boxcar << ActiveSalesforce::BoxcarCommand::Delete.new(self, ids_element)
        }
      end
      
      
      def retrieve_field_values(object_type, fields, ids, name = nil) 
        msg = "retrieve(#{object_type}, [#{ids.to_a.join(', ')}])"
        log(msg, name) {
          retrieve_element = []      
          retrieve_element << :fieldList << fields.to_a.join(", ")
          retrieve_element << 'type { :xmlns => "urn:sobject.partner.soap.sforce.com" }' << object_type
          ids.to_a.each { |id| retrieve_element << :ids << id }
          
          result = get_result(@connection.retrieve(retrieve_element), :retrieve)
          
          result = [ result ] unless result.is_a?(Array)
          
          # Remove unwanted :type and normalize :Id if required
          result.map { |v| v.delete(:type); v[:Id] = v[:Id][0] if v[:Id].is_a? Array; v }
        }
      end
      
      
      def get_fields(columns, names, values, access_check) 
        fields = {}
        names.each_with_index do | name, n | 
          value = values[n]
          
          if value
            column = columns[name]
            
            raise SalesforceError.new(@logger, "Column not found for #{name}!") unless column
            
            value.gsub!(/''/, "'") if value.is_a? String
            
            include_field = ((not value.empty?) and column.send(access_check))            
            fields[column.api_name] = value if include_field
          end
        end
        
        fields      
      end
      
      
      def get_result(response, method)
        responseName = (method.to_s + "Response").to_sym
        finalResponse = response[responseName]
        
        raise SalesforceError.new(@logger, response[:Fault][:faultstring], response.fault) unless finalResponse
        
        result = finalResponse[:result]
      end       
      
      
      def check_result(result)
        result = [ result ] unless result.is_a?(Array)
        
        result.each do |r|
          raise SalesforceError.new(@logger, r[:errors], r[:errors][:message]) unless r[:success] == "true"
        end
        
        result
      end
      
      
      def get_entity_def(entity_name)
        cached_entity_def = @entity_def_map[entity_name]
        
        if cached_entity_def
          # Check for the loss of asf AR setup 
          entity_klass = class_from_entity_name(entity_name)
          
          configure_active_record cached_entity_def unless entity_klass.respond_to?(:asf_augmented?)
          
          return cached_entity_def 
        end
        
        log("Retrieving metadata for '#{entity_name}'", "get_entity_def()") {
          cached_columns = []
          cached_relationships = []
          
          begin
            metadata = get_result(@connection.describeSObject(:sObjectType => entity_name), :describeSObject)
            custom = false
          rescue SalesforceError => e
            # Fallback and see if we can find a custom object with this name
            @logger.debug("   Unable to find medata for '#{entity_name}', falling back to custom object name #{entity_name + "__c"}")
            
            metadata = get_result(@connection.describeSObject(:sObjectType => entity_name + "__c"), :describeSObject)
            custom = true
          end
          
          metadata[:fields].each do |field| 
            column = SalesforceColumn.new(field) 
            cached_columns << column
            
            cached_relationships << SalesforceRelationship.new(field, column) if field[:type] =~ /reference/i
          end
          
          relationships = metadata[:childRelationships]
          if relationships
            relationships = [ relationships ] unless relationships.is_a? Array
            
            relationships.each do |relationship|  
              if relationship[:cascadeDelete] == "true"
                r = SalesforceRelationship.new(relationship)
                cached_relationships << r
              end
            end
          end
          
          key_prefix = metadata[:keyPrefix]
          
          entity_def = ActiveSalesforce::EntityDefinition.new(self, entity_name, 
            cached_columns, cached_relationships, custom, key_prefix)
            
          @entity_def_map[entity_name] = entity_def
          @keyprefix_to_entity_def_map[key_prefix] = entity_def
          
          configure_active_record entity_def
          
          entity_def
        }
      end
      
      
      def configure_active_record(entity_def)
        entity_name = entity_def.name
        klass = class_from_entity_name(entity_name)
        
        class << klass
          def asf_augmented?
            true
          end
        end
        
        klass.set_inheritance_column nil
        klass.set_primary_key "id" 
        klass.lock_optimistically = false
        klass.record_timestamps = false
        klass.default_timezone = :utc 
        
        # Create relationships for any reference field
        entity_def.relationships.each do |relationship|
          referenceName = relationship.name
          unless self.respond_to? referenceName.to_sym or relationship.reference_to == "Profile" 
            reference_to = relationship.reference_to
            one_to_many = relationship.one_to_many
            foreign_key = relationship.foreign_key
            
            # DCHASMAN TODO Figure out how to handle polymorphic refs (e.g. Note.parent can refer to 
            # Account, Contact, Opportunity, Contract, Asset, Product2, <CustomObject1> ... <CustomObject(n)>
            if reference_to.is_a? Array
              @logger.debug("   Skipping unsupported polymophic one-to-#{one_to_many ? 'many' : 'one' } relationship '#{referenceName}' from #{entity_name} to [#{relationship.reference_to.join(', ')}] using #{foreign_key}")
              next 
            end
            
            # Handle references to custom objects
            reference_to = reference_to.chop.chop.chop.capitalize if reference_to.match(/__c$/)
            
            begin
              referenced_klass = class_from_entity_name(reference_to)
            rescue NameError => e
              # Automatically create a least a stub for the referenced entity
              @logger.debug("   Creating ActiveRecord stub for the referenced entity '#{reference_to}'")
              
              referenced_klass = klass.class_eval("::#{reference_to} = Class.new(ActiveRecord::Base)")
              
              # configure_active_record(get_entity_def(reference_to))
            end
            
            if one_to_many
              klass.has_many referenceName.to_sym, :class_name => reference_to, :foreign_key => foreign_key, :dependent => false
            else
              klass.belongs_to referenceName.to_sym, :class_name => reference_to, :foreign_key => foreign_key, :dependent => false
            end
            
            #@logger.debug("   Created one-to-#{one_to_many ? 'many' : 'one' } relationship '#{referenceName}' from #{entity_name} to #{relationship.reference_to} using #{foreign_key}")
            
          end
        end
        
      end
      
      
      def columns(table_name, name = nil)
        entity_name = entity_name_from_table(table_name)
        get_entity_def(entity_name).columns
      end
      
      
      def columns_map(table_name, name = nil)
        entity_name = entity_name_from_table(table_name)
        get_entity_def(entity_name).column_name_to_column
      end
      
      
      def entity_name_from_table(table_name)
        return table_name.singularize.camelize
      end
      
      
      def class_from_entity_name(entity_name)
          entity_klass = @class_to_entity_map[entity_name.upcase]
          @logger.debug("Found matching class '#{entity_klass}' for entity '#{entity_name}'") if entity_klass
          
          entity_klass = entity_name.constantize unless entity_klass
                    
          entity_klass
      end
      
      
      def create_sobject(entity_name, id, fields)
        entity_def = get_entity_def(entity_name)
        
        sobj = []
        
        sobj << 'type { :xmlns => "urn:sobject.partner.soap.sforce.com" }' << entity_def.api_name
        sobj << 'Id { :xmlns => "urn:sobject.partner.soap.sforce.com" }' << id if id    
        
        # now add any changed fields
        fieldValues = {}
        fields.each do | name, value |
          sobj << name.to_sym << value if value
        end
        
        [ :sObjects, sobj ]
      end
      
      
      def column_names(table_name)
        columns(table_name).map { |column| column.name }
      end
      
      
      def api_column_names(table_name)
        columns(table_name).map { |column| column.api_name }
      end
      
    end
    
  end
end
