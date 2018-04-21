class ErrorReportsController < ApplicationController
  prepend_before_action :setup_user, except: [:create, :resolution]
  before_action :verify_ownership, except: [:create, :resolution]
  before_action :find_report, only: [:show, :update, :resolution]
  layout :determine_layout

  def create
    digest = Digest::MD5.hexdigest(params[:report][:body])
    logger.info("----------> digest: #{digest}")

    @error_report = ErrorReport.where('digest=?', digest).first
    if @error_report
      @ok = true
      @header = _('Error report exists')
      @result = { 'message' => 'Error report exists', 'id' => @error_report.id }
    else
      @error_report = ErrorReport.new(params[:report])
      @error_report.digest = digest
      @error_report.submit_time = Time.now
      @error_report.status = ErrorReport::OPEN
      @ok = @error_report.save
      if @ok
        @header = _('Error report submitted')
        @result = { 'message' => 'Error report created', 'id' => @error_report.id }
      else
        @header = _('Error report could not be created')
        @result = { 'message' => 'Error report could not be be created' }
      end
    end
    respond_to do |format|
      format.html
      format.xml
    end
  end

  def show
    @header = 'Error report details'
    session[:error_report_id] = @error_report.id
  end

  def resolution
    @header = _('Error resolution: %s') % ErrorReport::ERROR_REPORT_STATUS[@error_report.status | ERROR_REPORT_NEW]
    @display_report = if @error_report.resolution.blank?
                        "Your report was received and will be handled as soon as possible.\nYou can bookmark the URL (address) of this page and check back later."
                      else
                        @error_report.resolution
                      end
  end

  def edit_resolution
    begin
      @error_report = ErrorReport.find(session[:error_report_id])
    rescue
      redirect_to action: :index
      return false
    end

    @show_resolution_edit = nil # set the default value - don't show the list
    req = params[:req]
    if req == 'show'
      @show_resolution_edit = true
    elsif req.nil?
      @error_report.update_attributes!(params[:error_report])
    end

  end

  def update
    @error_report.update_attributes(params[:report])
    render action: :show
  end

  def index
    @header = 'Error reports'

    @pager = ::Paginator.new(ErrorReport.count, PER_PAGE) do |offset, per_page|
      ErrorReport.limit(per_page).offset(offset).order('id DESC')
    end
    @error_reports_page = @pager.page(params[:page])
    @list_of_pages = []
    for idx in 1..@pager.number_of_pages
      @list_of_pages << idx
    end
    @show_number_of_pages = (@pager.number_of_pages > 1)
  end

  private

  def verify_ownership
    unless @user.has_supporter_privileges?
      set_err('You are not authorized to view this')
      false
    end
  end

  def find_report

    @error_report = ErrorReport.find(params[:id])
  rescue
    set_err('Cannot find this error report')
    return false

  end

end
