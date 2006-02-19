require 'test/unit'
require 'mock_binding'

 
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


require 'pp'

module Asf
  module UnitTests

    module RecordedTestCase
      @@config = YAML.load_file(File.dirname(__FILE__) + '/config.yml').symbolize_keys
    
      attr_reader :connection
      
      
      def recording?
        @recording
      end
      
      
      def config
        @@config
      end
      
      
      def setup
        url = 'https://www.salesforce.com/services/Soap/u/7.0'
    
        @recording = ((not File.exists?(recording_file_name)) or config[:recording])
        
        @connection = MockBinding.new(url, nil, recording?)
            
        unless recording?
          File.open(recording_file_name) do |f|
            connection.load(f)
          end
        end
        
        response = connection.login(config[:username], config[:password])  
      end
      
      
      def teardown
        if recording?
          File.open(recording_file_name, "w+") do |f|
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