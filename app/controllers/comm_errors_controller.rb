class CommErrorsController < ApplicationController

  prepend_before_action :setup_user_optional
  prepend_before_action :locate_error, except: [:index, :new, :create]
  prepend_before_action :locate_parents

  layout :determine_layout
  include NotifyTas

  def index
    @comm_errors = @cms_request.comm_errors
    respond_to do |format|
      format.html
      format.xml
    end
  end

  def new
    @header = 'For debug - create a comm error'
  end

  def create
    comm_error = CommError.new(params[:comm_error])
    comm_error.cms_request = @cms_request
    comm_error.status = COMM_ERROR_ACTIVE

    if comm_error.error_code == COMM_ERROR_HTML_PARSE_ERROR
      # @ToDo create a support ticket
      comm_error.cms_request.update_attributes(status: CMS_REQUEST_FAILED,
                                               error_description: 'HTML Syntax Error')
    end

    @result = if comm_error.save
                { 'message' => 'Error created OK', 'id' => comm_error.id }
              else
                { 'message' => 'Error could not be created' }
              end

    respond_to do |format|
      format.html
      format.xml
    end
  end

  def update
    message = params[:message]
    @result = if @comm_error.update_attributes(params[:comm_error])
                { 'message' => 'Error updated OK' }
              else
                { 'message' => 'Error could not be updated' }
              end

    respond_to do |format|
      format.html
      format.xml
      format.js
    end
  end

  def retry
    if @comm_error.error_code == COMM_ERROR_FAILED_TO_CREATED_PROJECT
      tas_comm = TasComm.new
      @tas_request_notification_sent = true # for testing
      tas_session = tas_comm.notify_about_request(@cms_request, TAS_COMMAND_NEW_CMS_REQUEST, logger)
      @message = 'Resent project setup notification'
    elsif @comm_error.error_code == COMM_ERROR_FAILED_TO_RETURN_TRANSLATION
      number_of_notifications_sent = 0

      notification_sent = false
      @cms_request.versions_to_output.each do |version|
        if send_version_notifications(version, version.normal_user, false)
          number_of_notifications_sent += 1
          notification_sent = true
        end
      end

      if notification_sent
        @cms_request.following_requests.each do |f_cms_request|
          f_revision = f_cms_request.revision
          sent_for_this = false
          if f_revision
            f_cms_request.versions_to_output.each do |f_version|
              logger.info "CMS_REQUEST_FOLLOWING: Checking revision.#{f_revision.id}, version.#{f_version.id}"
              sent_for_this_translator = send_version_notifications(f_version, f_version.normal_user, true)
              logger.info "--- sent: #{sent_for_this_translator}"
              if sent_for_this_translator
                number_of_notifications_sent += 1
                sent_for_this = true
              end
            end
          end
          break unless sent_for_this
        end
      end

      @message = 'Sent %d output notifications' % number_of_notifications_sent
    end

    respond_to do |format|
      format.html do
        flash[:notice] = @message if @message
        redirect_to(controller: '/websites', action: :comm_errors, id: @website.id)
      end
      format.xml
    end
  end

  private

  def locate_parents
    begin
      @website = Website.find(params[:website_id].to_i)
    rescue
      set_err('Cannot locate website')
      return false
    end

    begin
      @cms_request = CmsRequest.find(params[:cms_request_id].to_i)
      if @cms_request.website != @website
        set_err('cms request does not belong to website')
        return false
      end
    rescue
      set_err('Cannot locate cms request')
      return false
    end
  end

  def locate_error
    begin
      @comm_error = CommError.find(params[:id].to_i)
    rescue
      set_err('Cannot locate comm error')
      return false
    end
    if @comm_error.cms_request != @cms_request
      set_err("Error doesn't belong to this request")
      return false
    end
  end

  def setup_user_optional
    accesskey = params[:accesskey]

    if accesskey
      if accesskey == @website.accesskey
        @user = @website.client
      else
        set_err('cannot access')
        return false
      end
    else
      if setup_user
        if (@user[:type] != 'Client') || (@website.client != @user)
          set_err("Website doesn't belong to you")
          return false
        end
      else
        return false
      end
    end

  end

end
