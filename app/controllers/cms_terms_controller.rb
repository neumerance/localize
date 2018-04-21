class CmsTermsController < ApplicationController
  prepend_before_action :setup_user
  # before_filter :verify_client, :except=>[:assign_to_me]
  before_action :locate_website
  before_action :locate_term, except: [:index, :create]
  layout :determine_layout

  def index
    setup_display_filters
    cms_identifier = params[:cms_identifier]
    @cms_terms = if @kind
                   @website.cms_terms.where('(parent_id IS NULL) AND (kind=?) AND (cms_identifier=?)', @kind, cms_identifier)
                 else
                   @website.cms_terms.where('(parent_id IS NULL) AND (cms_identifier=?)', cms_identifier)
                 end
    respond_to do |format|
      format.html
      format.xml
    end
  end

  def create
    cms_term = CmsTerm.new(params[:cms_term])
    cms_term.website = @website
    begin
      @result = if cms_term.save
                  { 'message' => 'Term created', 'id' => cms_term.id }
                else
                  { 'message' => 'Term cannot be saved' }
                end
    rescue
      @result = { 'message' => 'Duplicate term already exists' }
    end

    respond_to do |format|
      format.html
      format.xml
    end

  end

  def update
    @result = if @cms_term.update_attributes(params[:cms_term])
                { 'message' => 'Term updated' }
              else
                { 'message' => 'Term cannot be updated' }
              end

    respond_to do |format|
      format.html
      format.xml
    end

  end

  def destroy
    @cms_term.destroy
    @result = { 'message' => 'Term deleted' }
    respond_to do |format|
      format.html
      format.xml
    end
  end

  def show
    setup_display_filters
    respond_to do |format|
      format.html
      format.xml
    end
  end

  private

  def locate_website
    begin
      @website = Website.find(params[:website_id].to_i)
    rescue
      set_err('Cannot locate website')
      return false
    end
    if @website.client != @user
      set_err("Website doesn't belong to you")
      return false
    end
  end

  def locate_term
    begin
      @cms_term = CmsTerm.find(params[:id].to_i)
    rescue
      set_err('Cannot locate term')
      return false
    end
    if @cms_term.website != @website
      set_err("Term doesn't belong to this website")
      return false
    end
  end

  def setup_display_filters
    @kind = params[:kind]
    @show_children = !params[:show_children].blank?
    @show_translation = !params[:show_translation].blank?
  end
end
