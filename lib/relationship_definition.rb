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
    
      attr_reader :name, :api_name, :foreign_key, :label, :reference_to, :one_to_many, :cascade_delete
      
      def initialize(source)
        if source[:childSObject]
          relationship = source
          
          @api_name = relationship[:relationshipName] ? relationship[:relationshipName] : relationship[:field].chop.chop
          @one_to_many = relationship[:relationshipName] != nil
          @cascade_delete = relationship[:cascadeDelete] == "true"
          @reference_to = relationship[:childSObject]
          @label = @name
          @foreign_key = column_nameize(relationship[:field])
        else
          field = source
          
          @api_name = field[:name].chop.chop
          @label = field[:label]
          @readonly = (field[:updateable] != "true" or field[:createable] != "true")          
          @reference_to = field[:referenceTo]
          @one_to_many = false
          @cascade_delete = false
          @foreign_key = column_nameize(field[:name])
        end

        @name = column_nameize(@api_name)

      end
    end
    
  end
end    
