require 'set'

module Salesforce

  class SObjectAttributes 
    include Enumerable
    
    def initialize(record, columns)
      @columns = columns
      @values = {}
      
      record.__xmlele.each do |qname, value| 
        name = qname.name

        # Replace nil element with nil
        value = nil if value.respond_to?(:xmlattr_nil) and value.xmlattr_nil
                           
        # Ids are returned in an array with 2 duplicate entries...
        value = value[0] if name == "Id"
            
        self[name] = value
      end
          
      clear_changed!
    end
    
    def [](key)
      @values[key].freeze
    end
    
    def []=(key, value)
      column = @columns[key]
      return unless column

      return if @values[key] == value && @values.include?(key)

      # Convert strings representation of dates and datetimes to date and time objects
      if column and (column.type == :date or column.type == :datetime)
        # DCHASMAN TODO Add date and datetime parsing code!
        @values[key] = value
      else
        @values[key] = (value) ? value : ""
      end
      
      @changed = Set.new unless @changed
      @changed.add(key)
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