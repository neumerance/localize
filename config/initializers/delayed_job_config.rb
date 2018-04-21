Delayed::Worker.destroy_failed_jobs = false
Delayed::Worker.sleep_delay = 10
Delayed::Worker.max_attempts = 2
# Delayed::Worker.max_run_time = 60.minutes
Delayed::Worker.read_ahead = 10
Delayed::Worker.default_queue_name = 'default'
Delayed::Worker.delay_jobs = !Rails.env.test?
Delayed::Worker.raise_signal_exceptions = :term
Delayed::Worker.logger = Logger.new(File.join(Rails.root, 'log', 'delayed_jobs.log'))
Delayed::Worker.backend = :active_record
Delayed::Worker.default_priority = 10

Delayed::Backend::ActiveRecord.configure do |config|
  config.reserve_sql_strategy = :default_sql
end

Delayed::Worker.class_eval do

  def handle_failed_job_with_notification(job, error)
    handle_failed_job_without_notification(job, error)
    application_trace = Rails.backtrace_cleaner.clean(error.backtrace, :silent)
    framework_trace = Rails.backtrace_cleaner.clean(error.backtrace, :noise)
    full_trace = Rails.backtrace_cleaner.clean(error.backtrace, :all)
    ExceptionMailer.notify_delayed_job_error(error, application_trace, framework_trace, full_trace).deliver_now
  end
  alias_method_chain :handle_failed_job, :notification

end
