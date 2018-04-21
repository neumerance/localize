class SiteNoticesController < ApplicationController
  prepend_before_action :setup_user
  before_action :verify_admin
  layout :determine_layout

  # GET /site_notices
  # GET /site_notices.xml
  def index
    @site_notices = SiteNotice.all

    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render xml: @site_notices }
    end
  end

  # GET /site_notices/1
  # GET /site_notices/1.xml
  def show
    @site_notice = SiteNotice.find(params[:id])

    respond_to do |format|
      format.html # show.html.erb
      format.xml  { render xml: @site_notice }
    end
  end

  # GET /site_notices/new
  # GET /site_notices/new.xml
  def new
    @site_notice = SiteNotice.new

    respond_to do |format|
      format.html # new.html.erb
      format.xml  { render xml: @site_notice }
    end
  end

  # GET /site_notices/1/edit
  def edit
    @site_notice = SiteNotice.find(params[:id])
  end

  # POST /site_notices
  # POST /site_notices.xml
  def create
    @site_notice = SiteNotice.new(params[:site_notice])

    respond_to do |format|
      if @site_notice.save
        flash[:notice] = 'SiteNotice was successfully created.'
        format.html { redirect_to(@site_notice) }
        format.xml  { render xml: @site_notice, status: :created, location: @site_notice }
      else
        format.html { render action: 'new' }
        format.xml  { render xml: @site_notice.errors, status: :unprocessable_entity }
      end
    end
  end

  # PUT /site_notices/1
  # PUT /site_notices/1.xml
  def update
    @site_notice = SiteNotice.find(params[:id])

    respond_to do |format|
      if @site_notice.update_attributes(params[:site_notice])
        flash[:notice] = 'SiteNotice was successfully updated.'
        format.html { redirect_to(@site_notice) }
        format.xml  { head :ok }
      else
        format.html { render action: 'edit' }
        format.xml  { render xml: @site_notice.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /site_notices/1
  # DELETE /site_notices/1.xml
  def destroy
    @site_notice = SiteNotice.find(params[:id])
    @site_notice.destroy

    respond_to do |format|
      format.html { redirect_to(site_notices_url) }
      format.xml  { head :ok }
    end
  end

  private

  def verify_admin
    unless @user.has_admin_privileges?
      set_err('You are not authorized to view this')
      false
    end
  end

end
