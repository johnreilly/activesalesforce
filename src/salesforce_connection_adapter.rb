require 'active_record/connection_adapters/abstract_adapter'
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
            
      puts "connected to Salesforce as #{connection.getUserInfo(nil).result['userFullName']}"
      
      ConnectionAdapters::SalesforceAdapter.new(connection, logger, [url, username, password], config)
    end
  end
  

  module ConnectionAdapters
    class SalesforceError < StandardError
    end
    
    class SalesforceAdapter < AbstractAdapter

      def initialize(connection, logger, connection_options, config)
        super(connection, logger)
        
        @connection_options, @config = connection_options, config
        @columns_name_map = {}
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
        records = @connection.query(:queryString => soql).result.records
        records = [ records ] unless records.is_a?(Array)

        result = []        
        records.each do |record|
          attributes = Salesforce::SObjectAttributes.new(columns_map(record["type"]), record)
          result << attributes
        end
        
        result
      end

      def select_one(sql, name = nil) #:nodoc:
        result = select_all(sql, name)
        result.nil? ? nil : result.first
      end

      def execute(sql, name = nil, retries = 2) #:nodoc:
        log(sql, name) { @connection.query(sql) }
      end

      def insert(sql, name = nil, pk = nil, id_value = nil, sequence_name = nil) #:nodoc:
        execute(sql, name = nil)
        id_value || @connection.insert_id
      end

      def create(sobject, name = nil) #:nodoc:
        result = @connection.create(sobject).result
        pp result
        
        raise SalesforceError, result.errors.message  unless result.success == "true"
        
        # @connection.affected_rows
      end
      
      def update(sobject, name = nil) #:nodoc:
        result = @connection.update(sobject).result
        pp result
        
        raise SalesforceError, result.errors.message  unless result.success == "true"
        
        # @connection.affected_rows
      end
      
      alias_method :delete, :update 

      def columns(table_name, name = nil)
        columns = []
        
        metadata = @connection.describeSObject(:sObjectType => table_name).result
        metadata.fields.each do |field| 
          columns << SalesforceColumn.new(field) 
        end
        
        columns
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
