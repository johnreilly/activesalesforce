require 'set'

module Salesforce

  class SObjectAttributes 
    include Enumerable
    
    def initialize(columns, record = nil)
      @columns = columns
      @values = {}
      
      if record 
        record.__xmlele.each do |qname, value| 
          name = qname.name
  
          # Replace nil element with nil
          value = nil if value.respond_to?(:xmlattr_nil) and value.xmlattr_nil
                             
          # Ids are returned in an array with 2 duplicate entries...
          value = value[0] if name == "Id"
              
          self[name] = value
        end
      else
        columns.values.each { |column| self[column.name] = nil }
      end
                 
      clear_changed!
    end
    
    def [](key)
      @values[key].freeze
    end
    
    def []=(key, value)
      column = @columns[key]
      return unless column
      
      value = nil if value == ""

      return if @values[key] == value and @values.include?(key)
      
      originalClass = value.class
      originalValue = value
      
      if value 
        # Convert strings representation of dates and datetimes to date and time objects
        case column.type
          when :date
            value = value.is_a?(Date) ? value : Date.parse(value)
          when :datetime
            value = value.is_a?(Time) ? value : Time.parse(value)
          else
            value = column.type_cast(value)
        end
      end

      @values[key] = value
      
      #puts "setting #{key} = #{value} [#{originalValue}] (#{originalClass}, #{value.class})"
      
      if not column.readonly
        @changed = Set.new unless @changed
        @changed.add(key)
      end
    end
    
    def include?(key)
      @values.include?(key)
    end
    
    def has_key?(key)
      @values.has_key?(key)
    end
    
    def length
      @values.length
    end
    
    def keys
      @values.keys
    end
    
    def clear
      @values.clear
      clear_changed
    end
    
    def clear_changed!
      @changed = nil
    end
    
    def changed?
      @changed != nil
    end
    
    def changed_fields
      @changed
    end
    
    
    # Enumerable support
    
    def each(&block)
      @values.each(&block)
    end
    
  end

end