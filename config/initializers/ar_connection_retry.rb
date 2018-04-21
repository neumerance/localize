Rails.application.config.after_initialize do
  config  = ActiveRecord::Base.configurations[Rails.env] || Rails.application.config.database_configuration[Rails.env]
  adapter = config['adapter']

  if adapter == 'mysql2'
    module ActiveRecord::ConnectionAdapters
      class Mysql2Adapter
        alias execute_without_retry execute

        def execute(*args)
          execute_without_retry(*args)
        rescue ActiveRecord::StatementInvalid => e
          if e.message =~ /server has gone away/i ||
             e.message =~ /Lost connection to MySQL server during query/i
            Logging.log_error(self, e)
            reconnect!
            retry
          else
            raise e
          end
        end
      end
    end
  end
end
