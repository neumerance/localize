Rails.application.configure do
  # Settings specified here will take precedence over those in config/application.rb.

  # In the development environment your application's code is reloaded on
  # every request. This slows down response time but is perfect for development
  # since you don't have to restart the web server when you make code changes.
  config.cache_classes = false

  config.public_file_server.enabled = true
  config.assets.digest = true

  # Do not eager load code on boot.
  config.eager_load = false

  # Show full error reports.
  config.consider_all_requests_local = true

  # Enable/disable caching. By default caching is disabled.
  if Rails.root.join('tmp/caching-dev.txt').exist?
    config.action_controller.perform_caching = true

    config.cache_store = :memory_store # , { size: 1024.megabytes }
    config.public_file_server.headers = {
      'Cache-Control' => 'public, max-age=172800'
    }
  else
    config.action_controller.perform_caching = false
    config.cache_store = :null_store
  end

  # Don't care if the mailer can't send.
  config.action_mailer.raise_delivery_errors = false
  config.action_mailer.perform_caching = false
  config.action_mailer.preview_path = "#{Rails.root}/lib/mailer_previews"

  # Print deprecation notices to the Rails logger.
  config.active_support.deprecation = :log

  # Raise an error on page load if there are pending migrations.
  config.active_record.migration_error = :page_load
  config.assets.raise_runtime_errors = true

  # Debug mode disables concatenation and preprocessing of assets.
  # This option may cause significant delays in view rendering with a large
  # number of complex assets.
  config.assets.debug = true

  # Suppress logger output for asset requests.
  config.assets.quiet = true

  # Raises error for missing translations
  # config.action_view.raise_on_missing_translations = true

  # Use an evented file watcher to asynchronously detect changes in source code,
  # routes, locales, etc. This feature depends on the listen gem.
  # config.file_watcher = ActiveSupport::EventedFileUpdateChecker
  config.action_mailer.logger = nil
  config.action_mailer.delivery_method = :smtp
  config.action_mailer.default_url_options = { host: 'localhost:3000' }

  Rails.application.routes.default_url_options[:host] = 'localhost:3000'
  Rails.application.routes.default_url_options[:protocol] = 'http'

  # config.lograge.enabled = true
  #
  # config.lograge.custom_options = lambda do |event|
  #   opts = {
  #     params: event.payload[:params],
  #     time:  %('#{event.time}'),
  #     user_type: event.payload[:user_type],
  #     remote_ip: event.payload[:ip],
  #     browser: event.payload[:headers]['HTTP_USER_AGENT'],
  #     referer: event.payload[:headers]['HTTP_REFERER']
  #   }
  #   if event.payload[:exception]
  #     quoted_stacktrace = %('#{Array(event.payload[:exception_object].backtrace.select { |bct| bct.starts_with?(Rails.root.to_s) }.map { |err| err.sub(Rails.root.to_s, '') }).to_json}')
  #     opts[:exception_type] = event.payload[:exception][0]
  #     opts[:exception_message] = event.payload[:exception][1]
  #     opts[:stacktrace] = quoted_stacktrace
  #   end
  #   opts
  # end

  # I commented this line because it cause an error.
  # undefined method lograge - JonJon
  # config.lograge.formatter = Lograge::Formatters::KeyValue.new

end

EMAIL_LINK_HOST = 'localhost:3000'.freeze
EMAIL_LINK_PROTOCOL = 'http://'.freeze

LOGIN_ARGS = {}.freeze

TAS_URL = 'localhost'.freeze
TAS_PORT = 50089

WEBTA_ENABLED = true
WEBTA_HOST = 'http://localhost:9000'.freeze
WEBTA_SERVICE = ''.freeze
# WEBTA_SERVICE = 'icl_local'.freeze

# enable or disable mock data in api
API_MOCK = true
