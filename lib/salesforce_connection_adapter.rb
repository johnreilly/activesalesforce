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
require File.dirname(__FILE__) + '/sobject_attributes'
require File.dirname(__FILE__) + '/salesforce_active_record'
require File.dirname(__FILE__) + '/column_definition'

ActiveRecord::Base.class_eval do
  include ActiveRecord::SalesforceRecord
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
      end
    end
    
    class SalesforceAdapter < AbstractAdapter
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
        if value.kind_of?(String) && column && column.type == :binary
          s = column.class.string_to_binary(value).unpack("H*")[0]
          "x'#{s}'"
        else
          super
        end
      end
      
      def quote_column_name(name) #:nodoc:
        "`#{name}`"
      end
      
      def quote_string(string) #:nodoc:
        string
      end
      
      def quoted_true
        "TRUE"
      end
      
      def quoted_false
        "FALSE"
      end
      
      
      # CONNECTION MANAGEMENT ====================================
      
      def active?
        true
      end
      
      def reconnect!
        connect
      end
      
      
      # DATABASE STATEMENTS ======================================
      
      def select_all(soql, name = nil) #:nodoc:
        log(soql, name)
        
        @connection.batch_size = @batch_size if @batch_size
        @batch_size = nil
        
        records = get_result(@connection.query(:queryString => soql), :query).records

        result = []        
        return result unless records
        
        records = [ records ] unless records.is_a?(Array)
        
        records.each do |record|
          attributes = Salesforce::SObjectAttributes.new(columns_map(record[:type]), record)
          result << attributes
        end
        
        result
      end
      
      def select_one(sql, name = nil) #:nodoc:
        result = select_all(sql, name)
        result.nil? ? nil : result.first
      end
      
      def create(sobject, name = nil) #:nodoc:
        check_result(get_result(@connection.create(sobject), :create))[:id]
      end
      
      def update(sobject, name = nil) #:nodoc:
        check_result(get_result(@connection.update(sobject), :update))
      end

      def delete(ids)
        puts "Delete #{ids}"
        check_result(get_result(@connection.delete(:ids => ids), :delete))
      end
        
      def get_result(response, method)
        responseName = (method.to_s + "Response").to_sym
        finalResponse = response[responseName]
        
        raise SalesforceError.new(response[:Fault].faultstring, response.fault) unless finalResponse
        
        result = finalResponse[:result]
      end        
      
      def check_result(result)
        raise SalesforceError.new(result[:Errors], result[:Errors].Message) unless result[:success] == "true"
        result
      end
                    
      def columns(table_name, name = nil)
        cached_columns = @columns_map[table_name]
        return cached_columns if cached_columns
        
        cached_columns = []
        @columns_map[table_name] = cached_columns

        cached_relationships = []
        @relationships_map[table_name] = cached_relationships

        metadata = get_result(@connection.describeSObject(:sObjectType => table_name), :describeSObject)
        
        metadata.fields.each do |field| 
          column = SalesforceColumn.new(field) 
          cached_columns << column
          
          cached_relationships << SalesforceRelationship.new(field) if field[:type] =~ /reference/i
        end

        metadata.childRelationships.each do |relationship|
          cached_relationships << SalesforceRelationship.new(relationship)
        end
        
        cached_columns
      end
      
      def relationships(table_name)
        cached_relationships = @relationships_map[table_name]
        return cached_relationships if cached_relationships

        # This will load column and relationship metadata        
        columns(table_name)

        @relationships_map[table_name]
      end
      
      def columns_map(table_name, name = nil)
        columns_map = @columns_name_map[table_name]
        return columns_map if columns_map
        
        columns_map = {}
        @columns_name_map[table_name] = columns_map
        
        columns(table_name).each { |column| columns_map[column.name] = column }
        
        columns_map
      end
      
      private
      
      def select(sql, name = nil)
        puts "select(#{sql}, (#{name}))"
        @connection.query_with_result = true
        result = execute(sql, name)
        rows = []
        if @null_values_in_each_hash
          result.each_hash { |row| rows << row }
        else
          all_fields = result.fetch_fields.inject({}) { |fields, f| fields[f.name] = nil; fields }
          result.each_hash { |row| rows << all_fields.dup.update(row) }
        end
        result.free
        rows
      end
    end
  end
end
