Rails.application.configure do
  # Settings specified here will take precedence over those in config/application.rb.

  # Code is not reloaded between requests.
  config.cache_classes = true

  # Eager load code on boot. This eager loads most of Rails and
  # your application in memory, allowing both threaded web servers
  # and those relying on copy on write to perform better.
  # Rake tasks automatically ignore this option for performance.
  config.eager_load = true
  config.enable_dependency_loading = true

  # Full error reports are disabled and caching is turned on.
  config.consider_all_requests_local       = false
  config.action_controller.perform_caching = true

  # Specifies the header that your server uses for sending files
  #  config.action_dispatch.x_sendfile_header = 'X-Sendfile'

  # Disable serving static files from the `/public` folder by default since
  # Apache or NGINX already handles this.
  config.public_file_server.enabled = ENV['RAILS_SERVE_STATIC_FILES'].present?

  # Compress JavaScripts and CSS.
  config.assets.js_compressor = :closure
  # config.assets.css_compressor = :sass

  # Do not fallback to assets pipeline if a precompiled asset is missed.
  config.assets.compile = true
  # Asset digests allow you to set far-future HTTP expiration dates on all assets,
  # yet still be able to expire them through the digest params.
  config.assets.digest = true

  # `config.assets.precompile` and `config.assets.version` have moved to config/initializers/assets.rb

  # Enable serving of images, stylesheets, and JavaScripts from an asset server.
  # config.action_controller.asset_host = 'http://assets.example.com'

  # Specifies the header that your server uses for sending files.
  # config.action_dispatch.x_sendfile_header = 'X-Sendfile' # for Apache
  # config.action_dispatch.x_sendfile_header = 'X-Accel-Redirect' # for NGINX

  # Mount Action Cable outside main process or domain
  # config.action_cable.mount_path = nil
  # config.action_cable.url = 'wss://example.com/cable'
  # config.action_cable.allowed_request_origins = [ 'http://example.com', /http:\/\/example.*/ ]

  # Force all access to the app over SSL, use Strict-Transport-Security, and use secure cookies.
  # config.force_ssl = true

  # Use the lowest log level to ensure availability of diagnostic information
  # when problems arise.
  # config.log_level = :debug

  # Prepend all log lines with the following tags.
  # config.log_tags = [ :request_id ]

  # Use a different cache store in production.
  # config.cache_store = :mem_cache_store
  config.cache_store = :memory_store, { size: 8192.megabytes }

  # Use a real queuing backend for Active Job (and separate queues per environment)
  # config.active_job.queue_adapter     = :resque
  # config.active_job.queue_name_prefix = "icanlocalize_#{Rails.env}"
  # config.action_mailer.perform_caching = false

  # Ignore bad email addresses and do not raise email delivery errors.
  # Set this to true and configure the email server for immediate delivery to raise delivery errors.
  # config.action_mailer.raise_delivery_errors = false

  config.action_mailer.delivery_method = :smtp
  config.action_mailer.default_url_options = { host: 'icanlocalize.com' }

  # Enable locale fallbacks for I18n (makes lookups for any locale fall back to
  # the I18n.default_locale when a translation cannot be found).
  config.i18n.fallbacks = true

  # Send deprecation notices to registered listeners.
  config.active_support.deprecation = :notify

  # Use default logging formatter so that PID and timestamp are not suppressed.
  config.log_formatter = ::Logger::Formatter.new

  # Use a different logger for distributed setups.
  # require 'syslog/logger'
  # config.logger = ActiveSupport::TaggedLogging.new(Syslog::Logger.new 'app-name')

  if ENV['RAILS_LOG_TO_STDOUT'].present?
    logger = ActiveSupport::Logger.new(STDOUT)
    logger.formatter = config.log_formatter
    config.logger = ActiveSupport::TaggedLogging.new(logger)
  end

  # config.lograge.enabled = true
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
  #
  # config.lograge.formatter = Lograge::Formatters::KeyValue.new
  # config.logger = GELF::Logger.new('192.168.1.83', 12219, 'WAN', facility: 'icl-rails')

  # Do not dump schema after migrations.
  config.active_record.dump_schema_after_migration = false
  Rails.application.routes.default_url_options[:host] = 'icanlocalize.com'
  Rails.application.routes.default_url_options[:protocol] = 'http'
end

# Change SUBDOMAIN to nil when deploying in main prod server
SUBDOMAIN = nil
EMAIL_LINK_HOST = "#{SUBDOMAIN.present? ? SUBDOMAIN : 'www'}.icanlocalize.com".freeze
EMAIL_LINK_PROTOCOL = 'https://'.freeze

LOGIN_ARGS = { only_path: false, protocol: 'https://' }.freeze

TAS_URL = 'localhost'.freeze
TAS_PORT = 50087

HM_CLIENT_ID = 2112

WEBTA_ENABLED = false
WEBTA_HOST = ''.freeze
WEBTA_SERVICE = ''.freeze

# enable or disable mock data in api
API_MOCK = false
