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
  module StringHelper
    def column_nameize(s)
      s.underscore
    end
  end
  
  module ConnectionAdapters
 
     class SalesforceRelationship
      include StringHelper
    
      attr_reader :name, :api_name, :custom, :foreign_key, :label, :reference_to, :one_to_many
      
      def initialize(source, column = nil)
        if source[:childSObject]
          relationship = source
          
          if relationship[:relationshipName]
            @api_name = relationship[:relationshipName]
            @one_to_many = true
            @label = @api_name
            @name = column_nameize(@api_name)
            @custom = false
          else 
            @api_name = relationship[:field]
            @one_to_many = relationship[:cascadeDelete] == "true"
            @label = relationship[:childSObject].pluralize
            @custom = relationship[:childSObject].match(/__c$/)

            name = relationship[:childSObject]
            name = name.chop.chop.chop if custom
            
            @name = column_nameize(name.pluralize)
            @name = @name + "__c" if custom
          end
          
          @reference_to = relationship[:childSObject]
          
          @foreign_key = column_nameize(relationship[:field])
          @foreign_key = @foreign_key.chop.chop << "id__c" if @foreign_key.match(/__c$/)
        else
          field = source
          
          @api_name = field[:name]
          @custom = field[:custom] == "true"
          
          @api_name = @api_name.chop.chop unless @custom
          
          @label = field[:label]
          @reference_to = field[:referenceTo]
          @one_to_many = false
          
          @foreign_key = column.name
          @name = column_nameize(@api_name)
        end
      end
    end
    
  end
end    
