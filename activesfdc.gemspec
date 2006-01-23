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

require 'rubygems'
SPEC = Gem::Specification.new do |s|
  s.name = "activesalesforce"
  s.version = "0.0.4"
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
  s.autorequire = "active_salesforce"
  s.has_rdoc = true
  s.extra_rdoc_files = ["README"]
  s.add_dependency("rails", ">= 1.0.0")
  s.add_dependency("builder", ">= 1.2.4")
end
