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

require File.dirname(__FILE__) + '/../../lib/rforce'


class MockBindingFactory
  def initialize(recording)
    @recording = recording
  end
  
  def create(url, sid)
    MockBinding.new(url, sid, @recording)
  end
end


class MockBinding < RForce::Binding
  
  #Connect to the server securely.
  def initialize(url, sid, recording)
    @recording = recording
    @recorded_responses = {}
    
    super(url, sid) if @recording
  end
  
  
  def save(f)
    Marshal.dump(@recorded_responses, f)
  end
  
  
  def load(f)
    @recorded_responses = Marshal.load(f)
  end
  
  
  #Call a method on the remote server.  Arguments can be
  #a hash or (if order is important) an array of alternating
  #keys and values.
  def call_remote(method, args)
    # Star-out any passwords
    safe_args = args.inject([]) {|memo, v| memo << (memo.last == :password ? "*" * v.length : v) }
    key = "#{method}(#{safe_args.join(':')})"
    
    if @recording
      response = super(method, args)
      @recorded_responses[key] = response
    else
      response = @recorded_responses[key]
      raise "Unable to find matching response for recorded request '#{key}'" unless response
    end
    
    response
  end
  
end
