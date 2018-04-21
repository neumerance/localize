# == Exception Handling for icl ==
module App
  module ErrorsHandling
    def handle_exception(exception)
      @exception = exception
      @application_trace = Rails.backtrace_cleaner.clean(exception.backtrace, :silent)
      @framework_trace = Rails.backtrace_cleaner.clean(exception.backtrace, :noise)
      @full_trace = Rails.backtrace_cleaner.clean(exception.backtrace, :all)

      logger.info "###### rescued with application_controller#handle_exception: #{exception.class} ##"
      logger.info " -> #{exception}: #{@application_trace.join("\n    -> ")}"

      if exception.is_a? JSONError
        set_json_error_message(exception)
        log_json_exception(exception) # no point in logging this as multiline log, does not works with Graylog
        render_json_error
        return
      end

      if exception.is_a? ActionController::RoutingError
        render_html_error exception
      else
        begin
          @user_click.register_error(exception) if @user_click
        rescue => e
          # Nothing here, means user is not logged in, no need to polute log with this info
        end

        begin
          ExceptionMailer.notify_error(@exception, @application_trace, @framework_trace, @full_trace, request, session).deliver_now
        rescue Exception => e
          Logger.new('log/email_notifier').error("Failed to send error message for #{@exception.inspect} with error: #{e.inspect}")
        end

        if request.format.html? && can_view_debug?
          render(layout: 'layouts/rescue_layout', file: "rescues/#{ShowExceptions.rescue_templates[exception.class.name]}.erb", status: status_code(exception))
          return
        else
          render_html_error exception
        end
      end
    end

    def render_html_error(exception)
      status = status_code(exception)
      locale_path = Rails.root.join('public', "#{status}.#{I18n.locale}.html") if I18n.locale
      path = Rails.root.join('public', "#{status}.html")

      if locale_path && File.exist?(locale_path)
        render(file: locale_path, status: status)
      elsif File.exist?(path)
        render(file: path, status: status)
      else
        render(status: status, nothing: true)
      end
    end

    private

    def status_code(exception)
      Rack::Utils.status_code(ShowExceptions.rescue_responses[exception.class.name])
    end

    def set_json_error_message(exception)
      @json_code = exception.code || JSON_GENERAL_ERROR
      @json_message = exception.message || 'An unexpected error occurred. Refer to translation proxy log for more info.'
      @json_http_status_code = exception.http_status_code || status_code(exception)
    end

    def log_json_exception(exception)
      logger.error '== JSON ERROR =='
      logger.error "Exception: #{exception}"
      logger.error "Custom Error Code: #{@json_code}"
      logger.error "HTTP Status Code: #{@json_http_status_code}"
      logger.error "Message: #{@json_message}"
      logger.error 'Backtrace:'
      logger.error " #{exception.backtrace.join("\n")}"
    end

    def render_json_error
      render json: @json_message, status: @json_http_status_code
    end

    def can_view_debug?
      Rails.env.development? || @user.try(:has_admin_privileges?) || session_was_started_as_admin
    end
  end
end
