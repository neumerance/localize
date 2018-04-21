# Add your own tasks in files placed in lib/tasks ending in .rake,
# for example lib/tasks/capistrano.rake, and they will automatically be available to Rake.

require File.expand_path('../config/application', __FILE__)
require 'rake'

if %w(test development).include?(Rails.env)
  require 'ci/reporter/rake/rspec'
  require 'ci/reporter/rake/minitest'
end

Icanlocalize::Application.load_tasks

if %w(test development).include?(Rails.env)
  task rspec: 'ci:setup:spec'
  task minitest: 'ci:setup:minitest'
end
