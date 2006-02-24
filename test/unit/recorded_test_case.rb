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


require 'test/unit'
require 'mock_binding'

require 'set'

require 'pp'


module Asf
  module UnitTests

    module RecordedTestCase
      LOGGER = Logger.new(STDOUT)
      @@config = YAML.load_file(File.dirname(__FILE__) + '/config.yml').symbolize_keys
    
      attr_reader :connection
      
      
      def recording?
        @recording
      end
      
      
      def config
        @@config
      end
      
      
      def initialize(test_method_name)
        super(test_method_name)
        
        @force_recording = Set.new
      end
      
      
      def force_recording(method)
        @force_recording.add(method)
      end


      def unforce_recording(method)
        @force_recording.delete(method)
      end
      
      
      def setup
        url = 'https://www.salesforce.com/services/Soap/u/7.0'
    
        @recording = (((not File.exists?(recording_file_name)) or config[:recording]) or @force_recording.include?(method_name.to_sym))
        
        @connection = MockBinding.new(url, nil, recording?)

        ActiveRecord::Base.logger = LOGGER
        ActiveRecord::Base.clear_connection_cache!
        ActiveRecord::Base.reset_column_information_and_inheritable_attributes_for_all_subclasses
        ActiveRecord::Base.establish_connection(:adapter => 'activesalesforce', :username => config[:username], 
          :password => config[:password], :binding => connection)
            
        unless recording?
          File.open(recording_file_name) do |f|
            puts "Opening recorded binding #{recording_file_name}"
            connection.load(f)
          end
        end
        
        response = connection.login(config[:username], config[:password])  
      end
      
      
      def teardown
        if recording?
          puts "Saving recorded binding #{recording_file_name}"

          File.open(recording_file_name, "w") do |f|
            connection.save(f)
          end
        end 
      end
    
      
      def recording_file_name
        File.dirname(__FILE__) + "/recorded_results/#{self.class.name.gsub('::', '')}.#{method_name}.recording"
      end
      
    end
    
  end
end