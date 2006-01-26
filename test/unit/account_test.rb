require File.join(File.dirname(__FILE__), '../../config/boot')
require File.dirname(__FILE__) + '/../test_helper'

require 'pp'

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
    acme = Account.new 
    acme.Name = "Acme"
    acme.save
    
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

    dutchCo2 = Account.new(:Name => "DutchCo2", :Website => "www.dutchco2.com") 
    dutchCo2.save
    
    dutchCo3 = Account.create(:Name => "DutchCo3", :Website => "www.dutchco3.com") 

    accounts = Account.create([ 
      { :Name => "DutchCo4", :Website => "www.dutchco4.com" },
      { :Name => "DutchCo5", :Website => "www.dutchco5.com" }])
  end 
  

  def test_destroy_account
    account = Account.create(:Name => "DutchADelete", :Website => "www.dutchcodelete.com") 
    account = Account.find_by_Id(account.Id)
    
    pp account.Parent
    
    puts "Getting CreatedBy"
    createdBy = account.CreatedBy
    createdBy = User.find_by_Id(account.CreatedById);
    puts createdBy.Email
        
    Account.delete(account.Id)
  end
     
end
