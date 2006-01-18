require File.join(File.dirname(__FILE__), '../../config/boot')

require_gem 'activesalesforce'
require  'salesforce_connection_adapter'

require File.dirname(__FILE__) + '/../test_helper'



class AccountTest < Test::Unit::TestCase
  def setup
    ActiveRecord::Base.allow_concurrency = true
  end
  
  def test_get_account 
    accounts = Account.find(:all)

    #accounts.each { |account| puts "#{account.Name}, #{account.Id}, #{account.LastModifiedById}" }
  
    acme = Account.find(:first, :conditions => ["Name = 'Acme'"])
  
    acme = Account.find_by_Id(acme.Id)

    acme = Account.find_by_Name_and_LastModifiedById('salesforce.com', acme.LastModifiedById)
  end

   
  def test_update_account
    acme = Account.find_by_Name('Acme')
        
    acme.Website = "http://www.dutchforce.com/#{Time.now}.jpg"
    acme.LastModifiedDate = Time.now
    
    acme.save
  end
 
  def test_create_account
    dutchCo = Account.new 
    dutchCo.Name = "DutchCo"
    dutchCo.Website = "www.dutchco.com"
    dutchCo.save
  end 
       
end
