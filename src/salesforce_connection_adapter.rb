require 'active_record/connection_adapters/abstract_adapter'
require 'salesforce_login'
require 'sobject_attributes'


module ActiveRecord
  class Base
    # Establishes a connection to the database that's used by all Active Record objects.
    def self.salesforce_connection(config) # :nodoc:
      puts "Using Salesforce connection!"

      config = config.symbolize_keys

      username = config[:username].to_s
      password = config[:password].to_s

      if config.has_key?(:organizationId)
        organizationId = config[:organizationId]
      else
        raise ArgumentError, "No organizationId specified. Missing argument: organizationId."
      end

      connection = SfdcLogin.new().proxy
      puts "connected to Salesforce as #{connection.getUserInfo(nil).result['userFullName']}"
      
      ConnectionAdapters::SalesforceAdapter.new(connection, logger, [username, password, organizationId], config)
    end

  end

  module ConnectionAdapters
    class SalesforceColumn < Column #:nodoc:
    end

    class SalesforceAdapter < AbstractAdapter

      def initialize(connection, logger, connection_options, config)
        super(connection, logger)
        
        @connection_options, @config = connection_options, config
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
          attributes = Salesforce::SObjectAttributes.new
          result << attributes
          
          record.__xmlele.each { |qname, value| attributes[qname.name] = value }
          
          attributes.clear_changed!
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

      def update(sql, name = nil) #:nodoc:
        execute(sql, name)
        @connection.affected_rows
      end

      alias_method :delete, :update #:nodoc:


      def add_limit_offset!(sql, options) #:nodoc
        if limit = options[:limit]
          unless offset = options[:offset]
            sql << " LIMIT #{limit}"
          else
            sql << " LIMIT #{offset}, #{limit}"
          end
        end
      end


      # SCHEMA STATEMENTS ========================================

      def structure_dump #:nodoc:
        select_all("SHOW TABLES").inject("") do |structure, table|
          structure += select_one("SHOW CREATE TABLE #{table.to_a.first.last}")["Create Table"] + ";\n\n"
        end
      end

      def tables(name = nil) #:nodoc:
        tables = []
        execute("SHOW TABLES", name).each { |field| tables << field[0] }
        tables
      end

      def indexes(table_name, name = nil)#:nodoc:
        indexes = []
        current_index = nil
        execute("SHOW KEYS FROM #{table_name}", name).each do |row|
          if current_index != row[2]
            next if row[2] == "PRIMARY" # skip the primary key
            current_index = row[2]
            indexes << IndexDefinition.new(row[0], row[2], row[1] == "0", [])
          end

          indexes.last.columns << row[4]
        end
        indexes
      end
      

      def columns(table_name, name = nil)#:nodoc:
        sql = "SHOW FIELDS FROM #{table_name}"
        columns = []
        
        metadata = @connection.describeSObject(:sObjectType => table_name).result
        metadata.fields.each do |field| 
          columns << SalesforceColumn.new(field.name, '')
        end
        
        columns
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
