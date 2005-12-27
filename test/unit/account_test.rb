require File.join(File.dirname(__FILE__), '../../config/boot')
require  '~/dev/activesfdc/trunk/ActiveSalesforce/src/salesforce_connection_adapter'
require File.dirname(__FILE__) + '/../test_helper'



class AccountTest < Test::Unit::TestCase

  def test_get_account 
    products = Account.find(:all)
    pp products
      
    products.each { |product| puts "#{product.Name}, #{product.Id}, #{product.LastModifiedById}, #{product.Description}" }
  
    acme = Account.find(:first, :conditions => ["Name = 'Acme'"])
    puts acme.Name
  
    acme = Account.find_by_Id(acme.Id)
    puts acme.Name

    acme = Account.find_by_Name_and_LastModifiedById('salesforce.com', acme.LastModifiedById)
    puts acme.Name
  end

  def test_update_account
    #return
    
    acme = Account.find_by_Name('Acme')
    puts acme.Name
        
    acme.Website = "http://www.dutchforce.com/myImage2.jpg"
    
    acme.save
  end
    
  def test_create_account
    #dutchCo = Account.new   
  end
  
end
