#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/rforce.rb'


class SalesforceLogin
  attr_reader :proxy
  
  def initialize(url, username, password) 
    puts "SalesforceLogin.initialize()"

    @proxy = RForce::Binding.new(url)
    
    login_result = @proxy.login(username, password).result
  end
end
