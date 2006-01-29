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

require 'pp'


module ActiveRecord  
  module ConnectionAdapters
    class SalesforceColumn < Column
      attr_reader :label, :readonly, :reference_to
      
      def initialize(field)
        @name = field[:name]
        @type = get_type(field[:type])
        @limit = field[:length]
        @label = field[:label]
        
        @text = [:string, :text].include? @type
        @number = [:float, :integer].include? @type
        
        @readonly = (field[:updateable] != "true" or field[:createable] != "true")
        
        if field[:type] =~ /reference/i
          @reference_to = field[:referenceTo]
          @one_to_many = false
          @cascade_delete = false
        end
      end
      
      def get_type(field_type)
          case field_type
            when /int/i
              :integer
            when /currency|percent/i
              :float
            when /datetime/i
              :datetime
            when /date/i
              :date
            when /id|string|textarea/i
              :text
            when /phone|fax|email|url/i
              :string
            when /blob|binary/i
              :binary
            when /boolean/i
              :boolean
            when /picklist/i
              :text
            when /reference/i
              :text
          end
      end
      
      def human_name
        @label
      end

    end
    
    class SalesforceRelationship
      attr_reader :name, :foreign_key, :label, :reference_to, :one_to_many, :cascade_delete
      
      def initialize(source)
        if source[:childSObject]
          relationship = source
          
          @name = relationship[:relationshipName] ? relationship[:relationshipName] : relationship[:field].chop.chop
          @one_to_many = relationship[:relationshipName] != nil
          @cascade_delete = relationship[:cascadeDelete] == "true"
          @reference_to = relationship[:childSObject]
          @label = @name
          @foreign_key = relationship[:field]
        else
          field = source
          
          @name = field[:name].chop.chop
          @label = field[:label]
          @readonly = (field[:updateable] != "true" or field[:createable] != "true")          
          @reference_to = field[:referenceTo]
          @one_to_many = false
          @cascade_delete = false
        end
      end
    end
    
  end
end    
