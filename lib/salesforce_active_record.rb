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

require File.dirname(__FILE__) + '/sobject_attributes'


module ActiveRecord
  # Active Records will automatically record creation and/or update timestamps of database objects
  # if fields of the names created_at/created_on or updated_at/updated_on are present. This module is
  # automatically included, so you don't need to do that manually.
  #
  # This behavior can be turned off by setting <tt>ActiveRecord::Base.record_timestamps = false</tt>.
  # This behavior can use GMT by setting <tt>ActiveRecord::Base.timestamps_gmt = true</tt>
  module SalesforceRecord 

    def self.append_features(base) # :nodoc:
      super
      
      base.class_eval do
        alias_method :create, :create_with_sforce_api
        alias_method :update, :update_with_sforce_api
      end
    end    
    
    def create_with_sforce_api
      return if not @attributes.changed?
      puts "create_with_sforce_api creating #{self.class}"
      id = connection.create(:sObjects => create_sobject())
      self.Id = id
      @attributes.clear_changed!
    end
    
    def update_with_sforce_api
      return if not @attributes.changed?
      puts "update_with_sforce_api updating #{self.class}('#{self.Id}')"
      connection.update(:sObjects => create_sobject())
      @attributes.clear_changed!
    end
    
    def create_sobject()
      fields = @attributes.changed_fields
      
      sobj = [ 'type { :xmlns => "urn:sobject.partner.soap.sforce.com" }', self.class.table_name ]
      sobj << 'Id { :xmlns => "urn:sobject.partner.soap.sforce.com" }' << self.Id if self.Id    
      
      # now add any changed fields
      fieldValues = {}
      fields.each do |fieldName|
        value = @attributes[fieldName]
        sobj << fieldName.to_sym << value if value
      end
      
      sobj
    end
    
  end 
  
  class Base
    set_inheritance_column nil
    lock_optimistically = false
    record_timestamps = false
    default_timezone = :utc
    
    def after_initialize() 
      sfdcObjectName = self.class.table_name
      if not @attributes.is_a?(Salesforce::SObjectAttributes)
        # Insure that SObjectAttributes is always used for our attributes
        originalAttributes = @attributes 
        
        @attributes = Salesforce::SObjectAttributes.new(connection.columns_map(sfdcObjectName))
        
        originalAttributes.each { |name, value| self[name] = value }
      end
      
      # Create relationships for any reference field
      connection.relationships(sfdcObjectName).each do |relationship|
        referenceName = relationship.name
        unless self.respond_to? referenceName.to_sym or relationship.reference_to == "Profile"
          one_to_many = relationship.one_to_many
          
          puts "Creating one-to-#{one_to_many ? 'many' : 'one' } relationship '#{referenceName}' from #{sfdcObjectName} to #{relationship.reference_to}"
          
          if one_to_many
            self.class.has_many referenceName.to_sym, :class_name => relationship.reference_to, :foreign_key => relationship.foreign_key, :dependent => false
          else
            self.class.belongs_to referenceName.to_sym, :class_name => relationship.reference_to, :foreign_key => relationship.name, :dependent => false
          end
        end
      end
    end
    
    def self.table_name
        # Undo weird camilization that messes with custom object names
        name = self.name
        name.last(6) == "Custom" ? name.first(name.length - 6) << "__c" : name
    end
    
    def self.primary_key
      "Id"
    end
    
    def self.construct_finder_sql(options)
      soql = "SELECT #{column_names.join(', ')} FROM #{table_name} "
      add_conditions!(soql, options[:conditions])
      soql
    end
    
    def self.construct_conditions_from_arguments(attribute_names, arguments)
      conditions = []
      attribute_names.each_with_index { |name, idx| conditions << "#{name} #{attribute_condition(arguments[idx])} " }
      [ conditions.join(" AND "), *arguments[0...attribute_names.length] ]
    end
    
    def self.count(conditions = nil, joins = nil)
      soql  = "SELECT Id FROM #{table_name} "
      add_conditions!(soql, conditions)
      
      count_by_sql(soql)
    end
    
    def self.count_by_sql(soql)
      connection.batch_size = 1
      connection.select_all(soql, "#{name} Count").length
    end     
          
    def self.delete(ids)
      connection.delete(ids)
    end
    
  end
end
