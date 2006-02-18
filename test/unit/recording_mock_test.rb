require 'test/unit'
require 'recording_mock'
require 'pp'

class RecordingMockTest < Test::Unit::TestCase
  def initialize
    @recording = ("RECORD".casecmp(ARGV[0]) == 0)
  end
  
  def test_login
    url = 'https://www.salesforce.com/services/Soap/u/7.0'
    connection = MockBinding.new(url, nil, @recording)
    
    response = connection.login('doug_chasman@yahoo.com', 'Maceymo@11')
    
    File.open("test_login.recording", "w+") do |f|
      connection.dump(f)
    end
    
    connection = MockBinding.new(url, nil, false)
    File.open("test_login.recording") do |f|
      connection.load(f)
    end
    
    pp connection
    
    response = connection.login('doug_chasman@yahoo.com', 'Maceymo@11')
    
    response
    
  end 
  
end
