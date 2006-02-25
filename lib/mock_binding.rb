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

require 'yaml'
require File.dirname(__FILE__) + '/rforce'


class MockBinding < RForce::Binding
  attr_reader :recorded_responses
  
  #Connect to the server securely.
  def initialize(url, sid, recording)
    @recording = recording
    @recorded_responses = {}
    
    super(url, sid) if @recording
  end
  
  
  def save(f)
    YAML.dump(@recorded_responses, f)
  end
  
  
  def load(f)
    @recorded_responses = YAML.load(f)
  end
  
  
  #Call a method on the remote server.  Arguments can be
  #a hash or (if order is important) an array of alternating
  #keys and values.
  def call_remote(method, args)
    # Blank out username and password
    safe_args = args.inject([]) {|memo, v| memo << ((memo.last == :username or memo.last == :password) ? "" : v) }
    key = "#{method}(#{safe_args.join(':')})"
    
    if @recording
      response = super(method, args)
      @recorded_responses[key] = response
    else
      response = @recorded_responses[key]
      
      unless response
        @recorded_responses.each do |request, reponse|
          #pp request
        end
        
        raise "Unable to find matching response for recorded request '#{key}'" 
      end
    end
    
    response
  end
  
end
