require_relative 'boot'

require 'rails/all'

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

# Load pry unless Ruby Mine or prduction
Bundler.require(:pry) unless ENV['RM_INFO'] || Rails.env.production?

module Icanlocalize
  class Application < Rails::Application
    # Settings in config/environments/* take precedence over those specified here.

    config.encoding = 'utf-8'
    # Configure sensitive parameters which will be filtered from the log file.
    config.filter_parameters += [:password]

    # Skip frameworks you're not going to use (only works if using vendor/rails)
    # config.frameworks -= [ :action_web_service, :action_mailer ]

    # Only load the plugins named here, by default all plugins in vendor/plugins are loaded
    # config.plugins = %W( exception_notification ssl_requirement )

    # Add additional load paths for your own custom dirs
    config.autoload_paths += Dir["#{config.root}/lib/**/"]
    config.autoload_paths += Dir["#{config.root}/components/**/"]
    config.autoload_paths += %W(#{Rails.root}/app/jobs)

    config.eager_load_paths += Dir["#{config.root}/components/**/"]

    # Force all environments to use the same logger level
    # (by default production uses :info, the others :debug)
    # config.log_level = :debug

    # Use SQL instead of Active Record's schema dumper when creating the test database.
    # This is necessary if your schema can't be completely dumped by the schema dumper,
    # like if you have constraints or database-specific column types
    # config.active_record.schema_format = :sql

    # Activate observers that should always be running
    # config.active_record.observers = :cacher, :garbage_collector

    # Make Active Record use UTC-base instead of local time
    config.active_record.default_timezone = :utc

    # Todo add strong parameter check. There are no attr_accessible during original app, this line replicates that functionality, but is recommended to implement strong paramaters - emartini 10/18/2016
    config.action_controller.permit_all_parameters = true

    config.action_mailer.smtp_settings = {
      address: Figaro.env.email_address,
      port: Figaro.env.email_port,
      enable_starttls_auto: true, # detects and uses STARTTLS
      user_name: Figaro.env.email_user_name,
      password: Figaro.env.email_password,
      authentication: Figaro.env.email_authentication.try(:to_sym),
      domain: Figaro.env.email_domain
    }
    config.action_mailer.perform_deliveries = true
    config.action_mailer.raise_delivery_errors = true

    # See Rails::Configuration for more options
    unless '1.9'.respond_to?(:force_encoding)
      String.class_eval do
        begin
          remove_method :chars
        rescue NameError
          # OK
        end
      end
    end

    config.active_job.queue_adapter = :delayed_job

    config.after_initialize do
      if PROFILER_ENABLED
        Bullet.enable = true
        Bullet.bullet_logger = true
        Bullet.console = true
        Bullet.rails_logger = true
        Bullet.add_footer = true
        Bullet.slack = { webhook_url: 'https://hooks.slack.com/services/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', channel: '#performance_alerts', username: 'notifier' }
      end
    end

    config.middleware.insert_before 0, Rack::Cors do
      allow do
        origins '*'
        resource '*', headers: :any, methods: [:get, :post, :put, :patch, :delete]
      end
    end

    # Allow WPML to load ICL in iframe.
    config.action_dispatch.default_headers['X-Frame-Options'] = 'ALLOWALL'

    # Rescue specific exceptions in controllers and return proper error statuses.
    config.action_dispatch.rescue_responses = {
      'JSON::ParserError' => :bad_request
    }
  end

  module ActiveRecord
    module Validations
      module ClassMethods
        # Intended for use with STI tables, helps ignore the type field
        def validates_overall_uniqueness_of(*attr_names)
          configuration = { message: 'has already been taken' }
          configuration.update(attr_names.pop) if attr_names.last.is_a?(Hash)
          validates_each(attr_names, configuration) do |record, attr_name, value|
            records = where("#{attr_name} = ?", value)
            record.errors.add(attr_name, configuration[:message]) if !records.empty? && (records[0].id != record.id)
          end
        end
      end
    end
  end
end
