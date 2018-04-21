Rails.application.configure do
  # Settings specified here will take precedence over those in config/application.rb

  # The production environment is meant for finished, "live" apps.
  # Code is not reloaded between requests
  config.cache_classes = true

  # Full error reports are disabled and caching is turned on
  config.consider_all_requests_local       = false
  config.action_controller.perform_caching = true

  # Specifies the header that your server uses for sending files
  # config.action_dispatch.x_sendfile_header = "X-Sendfile"

  # For nginx:
  # config.action_dispatch.x_sendfile_header = 'X-Accel-Redirect'

  # If you have no front-end server that supports something like X-Sendfile,
  # just comment this out and Rails will serve the files

  # See everything in the log (default is :info)
  config.log_level = :info

  # Use a different logger for distributed setups
  # config.logger = SyslogLogger.new

  # Use a different cache store in production
  # config.cache_store = :mem_cache_store
  config.cache_store = :memory_store, { size: 4096.megabytes }

  # Disable Rails's static asset server
  # In production, Apache or nginx will already do this
  config.public_file_server.enabled = false

  # Enable serving of images, stylesheets, and javascripts from an asset server
  # config.action_controller.asset_host = "http://assets.example.com"

  # Disable delivery errors, bad email addresses will be ignored
  # config.action_mailer.raise_delivery_errors = false
  config.action_mailer.delivery_method = :smtp
  config.action_mailer.default_url_options = { host: 'migration.icanlocalize.com' }

  # Enable threaded mode
  # config.threadsafe!

  # Enable locale fallbacks for I18n (makes lookups for any locale fall back to
  # the I18n.default_locale when a translation can not be found)
  config.i18n.fallbacks = true

  # Send deprecation notices to registered listeners
  config.active_support.deprecation = :notify

  config.eager_load = true
  config.enable_dependency_loading = true

  # config.lograge.enabled = true
  # config.lograge.custom_options = lambda do |event|
  #   opts = {
  #     params: event.payload[:params],
  #     time:  %('#{event.time}'),
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
  #
  # config.lograge.formatter = Lograge::Formatters::KeyValue.new
  # config.logger = GELF::Logger.new("192.168.1.83", 12201, "WAN", { :facility => "icl-migration" })

  Rails.application.routes.default_url_options[:host] = 'migration.icanlocalize.com'
  Rails.application.routes.default_url_options[:protocol] = 'https'
end

SUBDOMAIN = 'migration'.freeze
EMAIL_LINK_HOST = "#{SUBDOMAIN.present? ? SUBDOMAIN : 'www'}.icanlocalize.com".freeze
EMAIL_LINK_PROTOCOL = 'http://'.freeze

LOGIN_ARGS = {}.freeze

TAS_URL = 'localhost'.freeze
TAS_PORT = 50088

# enable or disable mock data in api
API_MOCK = false

WEBTA_ENABLED = true
WEBTA_HOST = ''.freeze
WEBTA_SERVICE = ''.freeze
