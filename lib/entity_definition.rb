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
require_gem 'rails', ">= 1.0.0"

require 'pp'


module ActiveSalesforce  
  class EntityDefinition
    attr_reader :name, :columns, :column_name_to_column, :api_name_to_column, :relationships
    
    def initialize(connection, name, columns, relationships, custom)
      @connection = connection
      @name = name
      @columns = columns
      @relationships = relationships
      @custom = custom
      
      @column_name_to_column = {}          
      @columns.each { |column| @column_name_to_column[column.name] = column }
      
      @api_name_to_column = {}
      @columns.each { |column| @api_name_to_column[column.api_name] = column }
    end
    
    def custom?
      @custom
    end
    
    def api_name
      @custom ? name + "__c" : name
    end
    
    def layouts
      return @layouts if @layouts
      
      # Lazy load Layout information
      response = @connection.binding.describeLayout(:sObjectType => api_name)
      @layouts = @connection.get_result(response, :describeLayout)
    end
    
  end
  
end    
