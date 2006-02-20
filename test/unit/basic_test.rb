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
      
      def initialize(test_method_name)
        super(test_method_name)
        
        #force_recording :test_get_created_by_from_contact
      end
      
      def setup
        puts "\nStarting test '#{self.class.name.gsub('::', '')}.#{method_name}'"

        super
          
        @contact = Contact.new
        contact.first_name = 'DutchTestFirstName'
        contact.last_name = 'DutchTestLastName'
        contact.home_phone = '555-555-1212'
        contact.save   
        
        contact.reload
      end
      
      def teardown
        contact.destroy if contact

        super
      end
      
      def test_count_contacts
        assert_equal 27, Contact.count
      end
      
      def test_create_a_contact
        contact.id
      end

      def test_save_a_contact
        contact.id
      end

      def test_find_a_contact
        c = Contact.find(contact.id)
        assert_equal contact.id, c.id
      end

      def test_find_a_contact_by_id
        c = Contact.find_by_id(contact.id)
        assert_equal contact.id, c.id
      end

      def test_find_a_contact_by_first_name
        c = Contact.find_by_first_name('DutchTestFirstName')
        assert_equal contact.id, c.id
      end
      
      def test_read_all_content_columns
        Contact.content_columns.each { |column| contact.send(column.name) }
      end
            
      def test_get_created_by_from_contact
        user = contact.created_by
        assert_equal contact.created_by_id, user.id
      end
 
      def test_add_notes_to_contact
        n1 = Note.new(:title => "My Title", :body => "My Body")
        n2 = Note.new(:title => "My Title 2", :body => "My Body 2")
        
        contact.notes << n1
        contact.notes << n2
        
        n1.save
        n2.save
      end
                  
    end

  end
end