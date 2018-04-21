# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = 'pothoven-attachment_fu'
  s.authors			  = ['Rick Olson', 'Steven Pothoven']
  s.summary			  = 'attachment_fu as a gem'
  s.description = "This is a fork of Rick Olson's attachment_fu adding Ruby 1.9 and Rails 3.2 and Rails 4 support as well as some other enhancements."
  s.email = 'steven@pothoven.net'
  s.homepage		  = 'http://github.com/pothoven/attachment_fu'
  s.version			  = '3.2.18'
  s.date = '2016-05-27'

  s.files = Dir.glob('{lib,vendor}/**/*') + %w(CHANGELOG LICENSE README.rdoc amazon_s3.yml.tpl rackspace_cloudfiles.yml.tpl)
  s.extra_rdoc_files = ['README.rdoc']
  s.rdoc_options = ['--inline-source', '--charset=UTF-8']
  s.require_paths = ['lib']
  s.rubyforge_project = 'nowarning'
  s.rubygems_version  = '1.8.29'

  s.specification_version = 2 if s.respond_to? :specification_version
end
