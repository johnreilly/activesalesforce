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
  module BoxcarCommand
  
    class Base
      def initialize(connection, method, args)
        @connection = connection
        @method = method
        @args = args
      end
      
      def execute
        response = @connection.binding.send(@method, @args)
        
        result = @connection.get_result(response, @method)
        
        @connection.check_result(result)
      end
    end
    
    
    class Insert < Base
      def initialize(connection, sobject, idproxy)
        super(connection, :create, sobject)
        @idproxy = idproxy
      end
      
      def execute
        @idproxy << super()[0][:id]
      end
    end
    
    
    class Update < Base
      def initialize(connection, sobject)
        super(connection, :update, sobject)
      end
    end
  
  
    class Delete < Base
      def initialize(connection, ids)
        super(connection, :delete, ids)
      end
    end

  end  
end    
