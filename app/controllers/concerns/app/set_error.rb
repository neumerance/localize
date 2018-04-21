module App
  module SetError
    DONT_LOG_ERRORS = [NOT_LOGGED_IN_ERROR].freeze

    def set_err(err_str, err_code = -1, redirect_url = nil)
      unless DONT_LOG_ERRORS.include? err_code
        log_custom(err_str, { err: 'set_err' }, :info)
      end

      @status = err_str
      @err_code = err_code

      # The "/" before the controller name is required when redirecting from
      # a namespaced controller to a non-namespaced controller.
      @to_controller = '/login'
      @to_action = :index

      if @user
        if @user.has_supporter_privileges?
          @to_controller = '/supporter'
          @to_action = :index
        elsif @user[:type] == 'Client'
          @to_controller = '/client'
          @to_action = :index
        elsif @user[:type] == 'Translator'
          @to_controller = '/translator'
          @to_action = :index
        end
      end

      flash[:notice] = @status

      @response_status_code ||= 200

      respond_to do |format|
        format.html do
          redirect_to controller: @to_controller, action: @to_action, next: redirect_url
        end
        format.js { render js: "location.href = '#{url_for(controller: @to_controller, action: @to_action)}'" }
        format.xml { render action: :blank, status: @response_status_code }
      end
    end

    def log_custom(message, tags = {}, mode = :error)
      tags[:tag] = 'custom_log'
      tags.keys.each do |key|
        message += " #{key}=#{tags[key]}"
      end
      case mode
      when :error
        Rails.logger.error message
      when :warn
        Rails.logger.warn message
      when :info
        Rails.logger.info message
      else
        log_custom("Not supported mode in log_custom: #{mode}", {})
      end
    end
  end
end
