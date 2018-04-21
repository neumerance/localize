source 'https://rubygems.org'
ruby '2.3.1'

### rails related ###
gem 'rails', '5.0.0.1'
gem 'activerecord-session_store', '>= 1.0.0'
# db driver
gem 'mysql2'

### app server ###
gem 'mongrel', '1.2.0.pre2'
gem 'mongrel_cluster', '1.0.5'

### asset pipeline ###
# Use SCSS for stylesheets
gem 'sass-rails', '~> 5.0'
# Use to compile js
gem 'closure-compiler'
# Use jquery as the JavaScript library
gem 'jquery-rails'
# jquery ui to replace rjs visuals
gem 'jquery-ui-rails'

### pdf related ###
# Wicked PDF uses the shell utility wkhtmltopdf to serve a PDF file to a user from HTML.
gem 'wicked_pdf'
# Provides binaries for WKHTMLTOPDF project in an easily accessible package.
gem 'wkhtmltopdf-binary'

### get text ###
gem 'fast_gettext', '1.1.0'
gem 'gettext_i18n_rails', '1.7.2'
# rails-i18n provides translations for ActiveRecord validation error messages
gem 'rails-i18n'
# needed to collect translatable strings not needed at production
# no need to load the gem via require we only need the rake tasks
gem 'gettext', '>= 1.9.3', require: false, group: :development

### other dependencies ###
# ruby implementation of John Gruber's Markdown
gem 'BlueCloth', '1.0.1'
# character encoding auto-detection
gem 'rchardet', '~> 1.3', '>= 1.3.1'
# splitting apart documents into their component parts
gem 'docsplit', '0.7.6'
# A simple HTTP and REST client for Ruby, inspired by the Sinatra microframework style of specifying actions: get, put, post, delete.
gem 'rest-client', '1.7.3'
# Ferret is a super fast, highly configurable search library.
gem 'ferret'
# rubyzip is a ruby module for reading and writing zip files
gem 'rubyzip', '>= 1.2.0'
# fallback for old rybyzip versions
gem 'zip-zip'
# A DOT diagram generator for Ruby on Rail applications
gem 'railroad', '0.5.0'
# RMagick is an interface between Ruby and ImageMagick.
gem 'rmagick', '2.15.4'
# See also: http://logging.apache.org/log4j
gem 'log4r', '1.1.10'
# Ruby-GPGME is a Ruby language binding of GPGME (GnuPG Made Easy). It provides a High-Level Crypto API for encryption, decryption, signing, signature verification and key management.
gem 'gpgme', '2.0.10'
# GeoIP searches a GeoIP database for a given host or IP address
gem 'geoip', '1.6.1'
# Paginator is a simple pagination class that provides a generic interface suitable for use in any Ruby program.
gem 'paginator', '1.1.0'
# Improve the rendering of HTML emails by making CSS inline, converting links and warning about unsupported code.
gem 'premailer'
gem 'premailer-rails'
# A parser for XLIFF files
gem 'xliffer', '1.0.2', github: 'neohunter/xliffer'
# background jobs
gem 'delayed_job'
gem 'delayed_job_active_record'
# A common interface to multiple JSON libraries
gem 'multi_json', '>=1.2.0'
# .po and .mo file parser/generator
gem 'get_pomo', '0.9.3', github: 'neohunter/get_pomo'
# fork of Rick Olson's attachment_fu adding Ruby 1.9 and Rails 3.2 and Rails 4 support
gem 'pothoven-attachment_fu', path: File.join(File.dirname(__FILE__), '/lib/gems/pothoven-attachment_fu-3.2.18')
# replacement for responds_to_parent: enabling to submit multipart ajax form
gem 'remotipart', '~> 1.2'
# amazon sdk
gem 'aws-sdk', '~> 2'
# configuration management
gem 'figaro'

### Temporary. Review on rails 4 migration ###
gem 'acts_as_ferret' # ferret
gem 'rdig', github: 'glappen/rdig' # acts_as_ferret
# to make auto_link work in rails 4
gem 'rails_autolink'

# encrypted password
gem 'bcrypt'

# set cron jobs
gem 'whenever'

# Heavy metal SOAP client
gem 'savon', '~> 2.11.0'

gem 'highcharts-rails'

gem 'awesome_print', '1.8.0'
gem 'colorize'
gem 'coffee-rails'

# used to get users browser info
gem 'browser'

# run tasks accross multiple threads
gem 'parallel'

# used to create fake values
gem 'faker'

# markdown parser
gem 'redcarpet'

# emoji converter
gem 'rumoji'

# sql perfomance reporter
# gem 'bullet'

# send notifications on slack
gem 'slack-notifier'

# profiling
# gem 'ruby-prof'
# gem 'query_reviewer', github: 'nesquena/query_reviewer'
# gem 'rack-mini-profiler', require: false
# gem 'flamegraph'
# gem 'fast_stack'    # For Ruby MRI 2.0

# for pagination
gem 'kaminari'
# gem 'ruby-prof'
gem 'memory_profiler', '0.9.10'

group :development do
  # gem 'guard'
  # gem 'guard-test'
  # gem 'guard-brakeman'
  #
  # gem 'libnotify'
  gem 'derailed_benchmarks'
  gem 'stackprof' # For Ruby MRI 2.1+
end

group :pry do
  gem 'pry', '0.10.4'
  gem 'pry-byebug'
  # gem 'pry-remote'
  # gem 'interactive_editor'
end

group :development, :test, :sandbox do
  gem 'factory_girl_rails'
end

group :development, :test do

  gem 'rspec-rails', '~> 3.5.2'
  # Load RSpec faster with Spring
  gem 'spring-commands-rspec'
  gem 'database_cleaner'
  gem 'rails-controller-testing'

  gem 'minitest'
  gem 'minitest-skip'
  gem 'minitest-reporters'
  gem 'm'

  gem 'brakeman', require: false
  gem 'simplecov', require: false
  gem 'simplecov-rcov', require: false
  gem 'ci_reporter', require: false
  gem 'ci_reporter_rspec', require: false
  gem 'ci_reporter_minitest', require: false
  gem 'rspec_junit_formatter', require: false
  gem 'minitest-ci', require: false

  # library for mocking and stubbing compatible with test unit and minitest
  gem 'mocha', '1.1.0'
  gem 'flog', require: false

  gem 'rubocop', '0.46.0', require: false
  gem 'rubocop-checkstyle_formatter', require: false
  gem 'bundler-audit', require: false

  gem 'capistrano', '3.7.1'
  gem 'capistrano-rvm'
  gem 'capistrano-bundler'
  gem 'capistrano-rails'
  gem 'capistrano-passenger'
  gem 'capistrano-figaro-yml'
  # gem 'capistrano3-puma' #using passenger for now
  gem 'capistrano3-delayed-job', '~> 1.0'
  gem 'capistrano-rails-console', require: false
  gem 'capistrano-rails-tail-log'
  gem 'diffy'
end

gem 'mini_racer', platforms: :ruby

# token auth
gem 'jwt'
gem 'simple_command'

# CORS configs
gem 'rack-cors', require: 'rack/cors'

# gem 'active_model_serializers', '~> 0.10.0'
# http://jsonapi.org/

# OTGS segmenter

gem 'otgs-segmenter', '1.4.0'

# word counter
gem 'word_count_analyzer', '~> 1.0.0'

# sanitizer to remove html tags
gem 'sanitize', '~> 4.5.0'

# to decode html entities
gem 'htmlentities', '~> 4.0.0'

# gem 'shortcode'

# to view jobs on web
gem 'delayed_job_web'

# do not delete records
gem 'acts_as_paranoid', '~> 0.5.0'

# rails integr
gem 'jquery-datatables-rails'

# logs in AWS can't be stored on local disk, machine can be deleted at any time
# gem 'gelf'
# gem 'lograge'
# gem 'lograge-tagged'
