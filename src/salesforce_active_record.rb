# DCHASMAN TODO Add this to auto initiailization code to casue all Sfdc ActiveRecord objects to use the overrides

class Account < ActiveRecord::Base
  validates_format_of :Website, :with => %r{^http(s)?:.+\.(gif|jpg|png)$}i, :message => "must be a URL for a GIF, JPG, or PNG image"
  

  protected
  
  set_table_name self.name
  
  set_inheritance_column nil
        
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
    connection.select_all(soql, "#{name} Count").length
  end
end
