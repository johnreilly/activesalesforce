require 'rubygems'

#require_gem 'activesalesforce', '>= 0.2.6'
require 'activesalesforce'

require 'recorded_test_case'
require 'pp'


class Contact < ActiveRecord::Base
end


module Asf
  module UnitTests
    
    class BasicTest < Test::Unit::TestCase
      include RecordedTestCase
      
      attr_reader :contact
      
      def setup
        super

        Contact.establish_connection(:adapter => 'activesalesforce', :username => 'doug_chasman@yahoo.com', 
          :password => 'Maceymo@11', :binding => connection)
          
        @contact = Contact.new
        contact.first_name = 'Dutch'
        contact.last_name = 'Test'
        contact.home_phone = '555-555-1212'
        contact.save   
      end
      
      def teardown
        contact.destroy
        
        super
      end
    
      def test_create_a_contact
        contact.id
      end

      def test_save_a_contact
        contact.id
      end

      def test_read_all_content_columns
        Contact.content_columns.each { |column| contact.send(column.name) }
      end
            
      def test_read_nonexistent_attribute
        contact.first_name
      end
    
    end

  end
end