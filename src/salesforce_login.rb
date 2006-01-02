#!/usr/bin/env ruby

require 'cgi'
require 'pp'
require 'soap/header/simplehandler'

require File.dirname(__FILE__) + '/salesforce_soap.rb'

class SessionHeaderHandler < SOAP::Header::SimpleHandler
  HeaderName = XSD::QName.new('urn:partner.soap.sforce.com', 'SessionHeader')
  
  attr_accessor :sessionid
  
  def initialize
    super(HeaderName)
    @sessionid = nil
  end
  
  def on_simple_outbound
    if @sessionid
      {'sessionId' => @sessionid}
    else
      nil       # no header
    end
  end
end

class CallOptionsHandler < SOAP::Header::SimpleHandler
  HeaderName = XSD::QName.new('urn:partner.soap.sforce.com', 'CallOptions')
  
  attr_accessor :client
  
  def initialize
    super(HeaderName)
    @client = nil
  end
  
  def on_simple_outbound
    if @client
      {'client' => @client}
    else
      nil       # no header
    end
  end
end

class SalesforceLogin
  attr_reader :proxy
  
  def initialize(url, username, password) 
    puts "SalesforceLogin.initialize()"
    
    sessionid_handler = SessionHeaderHandler.new
    calloptions_handler = CallOptionsHandler.new
    calloptions_handler.client = 'sfdcOnRailsClient'
    
    @proxy = SalesforceSoap.new
    
    @proxy.endpoint_url = url if url
    
    @proxy.headerhandler << sessionid_handler
    @proxy.headerhandler << calloptions_handler
    #@proxy.wiredump_dev = STDOUT
    
    login_result = @proxy.login(:username => username, :password => password).result
    sessionid_handler.sessionid = login_result.sessionId
  end
end
