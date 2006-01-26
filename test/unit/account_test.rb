require File.join(File.dirname(__FILE__), '../../config/boot')
require File.dirname(__FILE__) + '/../test_helper'

require 'pp'

class ContactSControl
  def test_update_account
    account = Account.find_by_Name('Acme')
    
    pp account
  end
end
