class ResourceFormatsController < ApplicationController
  prepend_before_action :setup_user
  before_action :verify_admin
  layout :determine_layout

  # GET /resource_formats
  # GET /resource_formats.xml
  def index
    @resource_formats = ResourceFormat.all

    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render xml: @resource_formats }
    end
  end

  # GET /resource_formats/1
  # GET /resource_formats/1.xml
  def show
    @resource_format = ResourceFormat.find(params[:id])

    respond_to do |format|
      format.html # show.html.erb
      format.xml  { render xml: @resource_format }
    end
  end

  # GET /resource_formats/new
  # GET /resource_formats/new.xml
  def new
    @resource_format = ResourceFormat.new

    respond_to do |format|
      format.html # new.html.erb
      format.xml  { render xml: @resource_format }
    end
  end

  # GET /resource_formats/1/edit
  def edit
    @resource_format = ResourceFormat.find(params[:id])
  end

  # POST /resource_formats
  # POST /resource_formats.xml
  def create
    @resource_format = ResourceFormat.new(fix_nils(params[:resource_format]))

    respond_to do |format|
      if @resource_format.save
        flash[:notice] = 'ResourceFormat was successfully created.'
        format.html { redirect_to(@resource_format) }
        format.xml  { render xml: @resource_format, status: :created, location: @resource_format }
      else
        format.html { render action: 'new' }
        format.xml  { render xml: @resource_format.errors, status: :unprocessable_entity }
      end
    end
  end

  # PUT /resource_formats/1
  # PUT /resource_formats/1.xml
  def update
    @resource_format = ResourceFormat.find(params[:id])

    respond_to do |format|
      if @resource_format.update_attributes(fix_nils(params[:resource_format]))
        flash[:notice] = 'ResourceFormat was successfully updated.'
        format.html { redirect_to(@resource_format) }
        format.xml  { head :ok }
      else
        format.html { render action: 'edit' }
        format.xml  { render xml: @resource_format.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /resource_formats/1
  # DELETE /resource_formats/1.xml
  def destroy
    @resource_format = ResourceFormat.find(params[:id])

    if @resource_format.text_resources.count > 0
      flash[:notice] = "Cannot delete, there are #{@resource_format.text_resources.count} software localization projects using this format"
      redirect_to action: :index
      return
    end

    @resource_format.destroy

    respond_to do |format|
      format.html { redirect_to(resource_formats_url) }
      format.xml  { head :ok }
    end
  end

  private

  def fix_nils(params)
    res = {}
    params.each { |k, v| res[k] = v.blank? ? nil : v }
    res
  end

  def verify_admin
    unless @user.has_admin_privileges?
      set_err('You are not authorized to view this')
      false
    end
  end

end
