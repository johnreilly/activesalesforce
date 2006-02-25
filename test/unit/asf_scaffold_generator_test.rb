=begin
  ActiveSalesforce
  Copyright 2006 Doug Chasman
 
  Licensed under the Apache License, Version 2.0 (the "License");
  you may not use this file except in compliance with the License.
  You may obtain a copy of the License at
 
     http://www.apache.org/licenses/LICENSE-2.0
 
  Unless required by applicable law or agreed to in writing, software
  distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions and
  limitations under the License.
=end

require 'rubygems'

#require_gem 'activesalesforce', '>= 0.2.6'
require 'activesalesforce'

require 'recorded_test_case'
require 'pp'


class Contact < ActiveRecord::Base
end

class Department < ActiveRecord::Base
end


module Asf
  module UnitTests
    
    class AsfScaffoldGeneratorTest < Test::Unit::TestCase
      include RecordedTestCase
      
      attr_reader :contact
      
      def initialize(test_method_name)
        super(test_method_name)
        
        #force_recording :test_describe_layout
      end
      
      def setup
        puts "\nStarting test '#{self.class.name.gsub('::', '')}.#{method_name}'"

        super
      end
      
      def teardown
        super
      end


      def test_describe_layout
        entity_def = Contact.connection.get_entity_def("Contact")
        
        layouts = entity_def.layouts
        
        puts "<table>"
        layouts[:layouts][:detailLayoutSections].each do |section|
          rows = section[:layoutRows]
          rows = [ rows ] unless rows.is_a? Array
          
          rows.each do | row |
            puts "  <tr>"
            
            items = row[:layoutItems]
            items = [ items ] unless items.is_a? Array
            
            items.each do | item |
              puts "    <td>#{item[:label]}</td>"
              
              components = item[:layoutComponents]
              
              components = [ components ] unless components.is_a? Array
              
              puts "    <td>"
              components.each do |component|
                next if component.nil?
                
                if component[:type] == "Field"
                  field = component[:value]
                  column = entity_def.api_name_to_column[field]
                  
                  puts "@contact.#{column.name} "
                end
              end
              puts "    </td>"

            end
            
            puts "  </tr>"
          end
          
        end
        
        puts "</table>"
      end
      
    end
    
  end
end