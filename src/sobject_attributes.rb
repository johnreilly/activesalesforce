require 'set'

module Salesforce

  class SObjectAttributes 
    include Enumerable
    
    def initialize
      @values = {}
    end
    
    def [](key)
      @values[key].freeze
    end
    
    def []=(key, value)
      @values[key] = value
      
      puts "Setting #{key} = #{value}"
      
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