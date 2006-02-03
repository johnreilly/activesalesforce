require File.join(File.dirname(__FILE__), '../../config/boot')
require File.dirname(__FILE__) + '/../test_helper'

require 'pp'

class AccountTest < Test::Unit::TestCase
  def setup
    ActiveRecord::Base.allow_concurrency = true
  end

  def test_create_account
    dutchCo = Account.new 
    dutchCo.name = "DutchCo"
    dutchCo.website = "www.dutchco.com"
    dutchCo.save
    
    dutchCo2 = Account.new(:name => "DutchCo2", :website => "www.dutchco2.com") 
    dutchCo2.save
    
    dutchCo3 = Account.create(:name => "DutchCo3", :website => "www.dutchco3.com") 
    
    accounts = Account.create([ 
                              { :name => "DutchCo4", :website => "www.dutchco4.com" },
    { :name => "DutchCo5", :website => "www.dutchco5.com" }])
  end 
  
  def test_create_a_contact
    contact = Contact.find_by_id("0033000000B1LKpAAN")
    contact.first_name = "DutchieBoy"
    contact.save
  end
  
  
  def test_create_a_contact
    contact = Contact.new
  end
  
  
  def test_get_a_case_comment
    comment = CaseComment.find_by_parent_id('500300000011inJAAQ')
  end
  
  
  def test_one_to_many_relationship
    cases = Case.find_by_contact_id('0033000000B1LKrAAN')
    
    cases = [ cases ] unless cases.is_a?(Array)
    
    cases.each do |c| 
      puts "Case('#{c.id}', '#{c.subject}')"
      
      comments = c.case_comments      
      comments.each do |comment|
        puts "   CaseComment('#{comment.id}', '#{comment.comment_body}')"
      end
    end
  end
  
  def test_get_account 
    accounts = Account.find(:all)
    
    accounts.each { |account| puts "#{account.name}, #{account.id}, #{account.last_modified_by_id}" }
    
    acme = Account.find(:first, :conditions => ["name = 'Acme'"])
    
    acme = Account.find_by_id(acme.id)
    
    acme = Account.find_by_name_and_last_modified_by_id('salesforce.com', acme.last_modified_by_id)
  end
  
  def test_update_account
    acme = Account.new 
    acme.name = "Acme"
    acme.save
    
    acme = Account.find_by_name('Acme')
    
    acme.website = "http://www.dutchforce.com/#{Time.now}.jpg"
    acme.last_modified_date = Time.now
    
    acme.save
  end
  
  
  def test_destroy_account
    Account.new
    
    account = Account.create(:name => "DutchADelete", :website => "www.dutchcodelete.com") 
    account2 = Account.create(:name => "DutchADelete2", :website => "www.dutchcodelete2.com") 
    
    #pp account
    
    account = Account.find_by_id(account.id)
    
    pp account.parent
    
    createdBy = account.created_by
    createdBy = User.find_by_id(account.created_by_id);
    puts createdBy.email
    
    Account.delete([account.id, account2.id])
    
    account3 = Account.create(:name => "DutchADelete3", :website => "www.dutchcodelete3.com") 
    account3.destroy
  end
  
end
