require 'rubygems'
SPEC = Gem::Specification.new do |s|
  s.name = "activesalesforce"
  s.version = "1.0.0"
  s.author = "Doug Chasman"
  s.email = "dchasman@salesforce.com"
  s.homepage = "http://rubyforge.org/projects/activesfdc/"
  s.platform = Gem::Platform::RUBY
  s.summary = "ActiveSalesforce is an extension to the Rails Framework that allows for the dynamic creation and management of ActiveRecord objects through the use of Salesforce meta-data and uses a Salesforce.com organization as the backing store."
  candidates = Dir.glob("{bin,docs,lib,test}/**/*")
  
  s.files = candidates.delete_if do |item|
    #item.include?(".svn") || item.include?("rdoc")
  end 
   
  s.require_path = "lib"
  #s.autorequire = "momlog"
  #s.test_file = "test/ts_momlog.rb"
  s.has_rdoc = true
  s.extra_rdoc_files = ["README"]
  s.add_dependency("rails", ">= 1.0.0")
end
