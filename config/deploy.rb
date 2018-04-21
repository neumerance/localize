# config valid only for current version of Capistrano
lock '3.7.1'

set :application, 'otgsror'
set :stages, %w(production sandbox staging)

# Default branch is :master
# ask :branch, `git rev-parse --abbrev-ref HEAD`.chomp
# set :branch, ENV['BRANCH'] if ENV['BRANCH']

# Default deploy_to directory is /var/www/my_app_name
set :deploy_to, '~/rails_apps/icanlocalize'

set :deploy_via, :remote_cache
set :scm, 'git'

set :format, :airbrussh
set :format_options, command_output: true, log_file: 'log/capistrano.log', color: :auto, truncate: :auto

set :pty, true

set :passenger_restart_with_touch, true

append :linked_files, 'config/application.yml', 'config/schedule.rb'
append :linked_dirs, 'log', 'tmp/pids', 'tmp/cache', 'tmp/sockets', 'public/system', 'bin', 'private', 'public/images/production', 'public/images', 'public/javascripts', 'public/stylesheets'

set :keep_releases, 5
set :rvm_type, :user
set :rvm_ruby_version, '2.3.1@icanlocalize'

# set :delayed_job_workers, 6
