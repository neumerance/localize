module LogError
  def log_error(exception)
    Rails.logger.error("\n#{exception.class} (#{exception.message}):\n #{Rails.backtrace_cleaner.clean(exception.backtrace).join("\n")}")
  end
end
