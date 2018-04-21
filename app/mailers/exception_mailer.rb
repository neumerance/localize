class ExceptionMailer < ApplicationMailer

  def notify_error(exception, application_trace, framework_trace, full_trace, request, session, message = nil)

    @exception = exception
    @application_trace = application_trace
    @framework_trace = framework_trace
    @full_trace = full_trace
    @request = request
    @params = request.params
    @session = session
    @message = message

    mail(
      from: 'notify@icanlocalize.com',
      to:   EMAILS_TO_RECEIVE_ERRORS,
      subject: "[#{Rails.env.upcase}] - #{@exception.message}"
    )
  end

  def notify_delayed_job_error(exception, application_trace, framework_trace, full_trace)
    @exception = exception
    @application_trace = application_trace
    @framework_trace = framework_trace
    @full_trace = full_trace

    mail(
      from: 'notify@icanlocalize.com',
      to: EMAILS_TO_RECEIVE_ERRORS,
      subject: "[#{Rails.env.upcase}] DELAYED JOB - #{@exception.message}"
    )
  end

end
