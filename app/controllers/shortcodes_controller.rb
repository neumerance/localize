class ShortcodesController < ApplicationController
  prepend_before_action :locate_website
  prepend_before_action :setup_user
  before_action :check_permissions
  before_action :setup_help
  layout :determine_layout

  # GET /shortcodes
  # GET /shortcodes.xml
  def index
    @header = 'Blocked shortcodes list'
    @shortcodes = Shortcode.global

    respond_to do |format|
      format.html # index.html.erb
    end
  end

  # GET /shortcodes/new
  # GET /shortcodes/new.xml
  def new
    @shortcode = Shortcode.new

    respond_to do |format|
      format.html # new.html.erb
    end
  end

  # GET /shortcodes/1/edit
  def edit
    @shortcode = Shortcode.find(params[:id])
  end

  # POST /shortcodes
  # POST /shortcodes.xml
  def create
    @shortcode = Shortcode.new(params[:shortcode])
    @shortcode.creator = @user
    @shortcode.website = @website if @website

    respond_to do |format|
      if @shortcode.save
        format.html { redirect_to(shortcodes_url, notice: 'Shortcode was successfully created.') }
      else
        format.html { render action: 'new' }
      end
    end
  end

  # PUT /shortcodes/1
  # PUT /shortcodes/1.xml
  def update
    @shortcode = Shortcode.find(params[:id])

    respond_to do |format|
      if @shortcode.update_attributes(params[:shortcode].to_h)
        format.html { redirect_to(shortcodes_url, notice: 'Shortcode was successfully updated.') }
      else
        format.html { render action: 'edit' }
      end
    end
  end

  def toggle_enabled
    @shortcode = Shortcode.find(params[:id])
    result = nil

    if @website && @shortcode.global?
      ws = @website.website_shortcodes.find_or_initialize_by(shortcode_id: @shortcode.id)
      result = ws.toggle_enabled
    else
      result = @shortcode.toggle_enabled
    end

    respond_to do |format|
      if result
        format.html { redirect_to(shortcodes_url, notice: 'Shortcode was successfully updated.') }
      else
        format.html { render action: 'edit' }
      end
    end
  end

  # DELETE /shortcodes/1
  # DELETE /shortcodes/1.xml
  def destroy
    @shortcode = Shortcode.find(params[:id])
    @shortcode.destroy

    respond_to do |format|
      format.html { redirect_to(shortcodes_url) }
    end
  end

  private

  def shortcodes_url
    logger.info 'sohrtcodes url method'
    @website ? website_shortcodes_url(@website) : super
  end

  def check_permissions
    if @website
      verify_modify
    else
      verify_admin
    end
  end

  def verify_view
    unless @user.can_view?(@website)
      set_err("You can't do that.")
      return false
    end
    true
  end

  def verify_modify
    unless @user.can_modify?(@website)
      set_err("You can't do that.")
      return false
    end
    true
  end

  def verify_admin
    unless @user.has_admin_privileges?
      set_err('You cannot access this page')
      false
    end
  end

  def locate_website
    return unless params[:website_id]

    begin
      @website = Website.find(params[:website_id].to_i)
      # @ToDO validate ownership
      true
    rescue
      set_err('cannot find this website')
      return false
    end
  end

end
