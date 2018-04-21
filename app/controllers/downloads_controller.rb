class DownloadsController < ApplicationController
  prepend_before_action :setup_user
  layout :determine_layout
  before_action :verify_supporter, only: [:index, :new, :create, :destroy]
  before_action :setup_download, only: [:show, :get, :destroy]

  def index
    @downloads = Download.all
  end

  def new
    @header = 'Upload a new program'
    @download = Download.new
  end

  def create
    @download = Download.new(params[:download])
    respond_to do |format|
      if @download.save
        flash[:notice] = 'Uploaded OK.'
        format.html { redirect_to download_path(@download.id) }
      else
        @header = 'Upload a new program'
        format.html { render action: 'new', layout: 'standard' }
      end
    end
  end

  def show
    @header = 'Download details'
  end

  def get
    send_file(@download.full_filename)
    user_download = UserDownload.create!(user_id: @user.id, download_id: @download.id, download_time: Time.now)
  end

  def show_recent
    progname = params[:id]
    progname = progname.tr('+', ' ') unless progname.blank?
    downloads = Download.where('(generic_name=?) AND (usertype=?)', progname, @user[:type]).order('id DESC').first
    if downloads.present?
      @download = downloads
      @header = _('Recent version of %s') % progname
      # respond_to do |format|
      #	format.html { render :action=>:show }
      #	format.xml
      # end
    else
      @err_code = -1
      @header = _('Problem locating %s') % progname
    end
    respond_to do |format|
      format.html do
        render action: :show if @download
      end
      format.xml
    end
  end

  def destroy
    flash[:notice] = "Removed file #{@download.generic_name} #{@download.major_version}.#{@download.sub_version}"
    @download.destroy
    redirect_to action: :index
  end

  private

  def verify_supporter
    unless @user.has_admin_privileges?
      set_err('You are not allowed to do this')
      false
    end
  end

  def setup_download

    @download = Download.find(params[:id].to_i)
  rescue
    redirect_to '/'
    return false

  end

end
