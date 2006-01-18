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

require 'set'


module Salesforce

  class SObjectAttributes 
    include Enumerable
    
    def initialize(columns, record = nil)
      @columns = columns
      @values = {}
      
      if record 
        record.each do |name, value| 
          # Replace nil element with nil
          value = nil if value.respond_to?(:xmlattr_nil) and value.xmlattr_nil
                             
          # Ids are returned in an array with 2 duplicate entries...
          value = value[0] if name == :Id
              
          self[name.to_s] = value
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