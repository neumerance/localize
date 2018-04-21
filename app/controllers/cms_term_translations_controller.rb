class CmsTermTranslationsController < ApplicationController
  prepend_before_action :setup_user
  before_action :locate_website
  before_action :locate_translation, except: [:index, :create]
  layout :determine_layout

  def create
    cms_term_translation = CmsTermTranslation.new(params[:cms_term_translation])
    cms_term_translation.cms_term = @cms_term
    @result = if cms_term_translation.save
                { 'message' => 'Translation created', 'id' => cms_term_translation.id }
              else
                { 'message' => 'Translation cannot be saved' }
              end

    respond_to do |format|
      format.html
      format.xml
    end

  end

  def update
    @result = if @cms_term_translation.update_attributes(params[:cms_term_translation])
                { 'message' => 'Translation updated' }
              else
                { 'message' => 'Translation cannot be updated' }
              end

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

    begin
      @cms_term = CmsTerm.find(params[:cms_term_id].to_i)
    rescue
      set_err('Cannot locate term')
      return false
    end

    if @cms_term.website != @website
      set_err("Term doesn't belong to this website")
      return false
    end

    if @website.client != @user
      set_err("Website doesn't belong to you")
      return false
    end
  end

  def locate_translation
    begin
      @cms_term_translation = CmsTermTranslation.find(params[:id].to_i)
    rescue
      set_err('Cannot locate translation')
      return false
    end
    if @cms_term_translation.cms_term != @cms_term
      set_err("Translation doesn't belong to this term")
      return false
    end
  end
end
