puts "Yahoo"

require 'test/unit'
require File.dirname(__FILE__) + '/../../src/sobject_attributes'

class SobjectAttributesTest < Test::Unit::TestCase

  def setup 
    @attributes = Salesforce::SObjectAttributes.new 
  end
  
  def test_add_values() 
    assert((not @attributes.changed?))
    
    @attributes['name'] = 'value'    
    assert(@attributes.changed?)
    
    assert_equal('value', @attributes['name'])
    
    assert_equal(Set.new('name'), @attributes.changed_fields)

    @attributes.clear_changed!    
    assert((not @attributes.changed?))
    
    assert_equal('value', @attributes['name'])
  end
  
  def test_enumeration
    10.times { |n| @attributes["name_#{n}"] = "value_#{n}" }
    
    assert_equal(10, @attributes.length)
    
    5.times { |n| @attributes["name_#{n + 10}"] = "value_#{n + 10}" }
    
    @attributes.each { |name, value| assert_equal(name[/_\d/],  value[/_\d/]) }
  end
  
end
