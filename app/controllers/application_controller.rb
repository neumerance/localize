# Filters added to this controller apply to all controllers in the application.
# Likewise, all the methods added will be available for all controllers.

require 'rexml/document'
require 'rexml/streamlistener'
require 'paginator'
require 'xmlrpc/client'
require 'uri'
require 'net/https'
require 'cgi'
require 'rails_autolink'
require 'csv'

class ApplicationController < ActionController::Base

  NotAuthorized = Class.new(StandardError)

  # components
  include ChatFunctions
  include TransactionProcessor
  include NotifyTas

  # concerns
  include ::App::CreateRemindersList
  include ::App::DetermineLayout
  include ::App::DoVerifyOwnership
  include ::App::ErrorsHandling
  include ::App::Locale
  # include ::App::LogRequestCycle
  include ::App::MakeDict
  include ::App::Redirects
  include ::App::SessionManagement
  include ::App::SetError
  include ::App::SetSupportFile
  include ::App::SetupHelp
  include ::App::SetupNavigation
  include ::App::Verifications
  include ::App::UserAgent
  include ::App::Caching

  # translations
  include FastGettext
  include FastGettext::Translation

  protect_from_forgery unless: -> { request.format.json? || request.format.xml? }

  before_action :default_locale
  before_action :set_gettext_locale
  before_action :setup_navigation
  before_action :detect_browser
  before_action :set_per_page
  before_action :start_timer

  # prepend_before_action :log_info
  # after_action :log_request_end

  skip_after_action :verify_same_origin_request, only: :route_not_found

  rescue_from Exception, with: :handle_exception

  rescue_from(ActionController::UnknownFormat) do |e|
    raise ActionController::RoutingError.new('Not Found')
  end

  # Authorization error used for API requests
  rescue_from ApplicationController::NotAuthorized do |_exception|
    render_error_page(status: 401, text: 'Unauthorized')
  end

  # Authorization error used for HTML requests
  rescue_from Error::NotAuthorizedError, with: :user_not_authorized

  def user_not_authorized
    # This exception is rescued by Rails and a 404 page is rendered. We display
    # a 404 instead of 403 Forbidden for security reasons (prevent enumeration
    # of DB IDs).
    raise ActionController::RoutingError, 'Not Found'
  end

  def notify_error(exception, message = nil)
    @application_trace = Rails.backtrace_cleaner.clean(exception.backtrace, :silent)
    @framework_trace = Rails.backtrace_cleaner.clean(exception.backtrace, :noise)
    @full_trace = Rails.backtrace_cleaner.clean(exception.backtrace, :all)
    begin
      ExceptionMailer.notify_error(@exception, @application_trace, @framework_trace, @full_trace, request, session, message).deliver_now
    rescue Exception => e
      Logger.new('log/email_notifier').error("Failed to send error message for #{@exception.inspect} with error: #{e.inspect}")
    end
  end

  def route_not_found
    respond_to do |format|
      format.html { render 'error_pages/404', layout: nil, status: :not_found }
      format.any { head :not_found }
    end
  end

  def default_url_options
    { compact: params[:compact] }
  end

  # def append_info_to_payload(payload)
  #   super
  #   payload[:ip] = remote_ip(request)
  #   payload[:user_type] = @user.present? ? @user.class.to_s : 'Anonymous'
  #   unless @exception.nil?
  #     payload[:exception_object] = @exception
  #     payload[:exception] = [@exception.class.to_s, @exception.message]
  #   end
  # end

  private

  # def remote_ip(request)
  #   request.headers['HTTP_X_REAL_IP'] || request.headers['HTTP_X_FORWARDED_FOR'] || request.remote_ip
  # end

  def http_authetication
    users = { otgsror: 'cr0ss0ver@2016' }
    if Rails.env == 'sandbox'
      authenticate_or_request_with_http_digest do |username|
        users[username.to_sym]
      end
    end
  end

  def set_per_page
    params[:per_page] = (params[:per_page].to_i > 0) ? params[:per_page].to_i : 20
    params[:page] = (params[:page].to_i > 0) ? params[:page].to_i : 1
  end

  def list_errors(errors, html = true)
    concat = ''
    if html
      concat << '<ul>'
      errors.each do |message|
        concat << '<li>'
        concat << message
        concat << '</li>'
      end
      concat << '</ul>'
    else
      errors.each do |message|
        concat << message
        concat << "\n\n"
      end
    end
    concat
  end

  def start_timer
    @timer = Time.now
  end

  def render_error_page(status:, text:, template: 'errors/routing')
    respond_to do |format|
      format.json { render json: { errors: [message: "#{status} #{text}"] }, status: status }
      format.html { render template: template, status: status, layout: false }
      format.any { head status }
    end
  end

end
