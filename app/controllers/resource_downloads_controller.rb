class ResourceDownloadsController < ApplicationController
  prepend_before_action :setup_user, except: [:download, :download_mo]
  prepend_before_action :setup_user_optional, only: [:download, :download_mo]
  before_action :locate_parent
  before_action :locate_download, except: [:index, :new, :create]
  before_action :verify_client, except: [:download, :download_mo]
  before_action :verify_client_optional, only: [:download, :download_mo]
  before_action :setup_help, except: [:download, :download_mo]
  layout :determine_layout

  include CharConversion

  def show
    @header = _('Translated resource file')
    @decoded = !params[:decode].blank?
    @file_contents = @resource_download.get_contents
    resource_format = @resource_download.upload_translation.resource_upload.resource_upload_format.resource_format
    if @decoded
      @file_contents = unencode_string(@file_contents, resource_format.encoding)
    end
    @can_decode = (resource_format.encoding != ENCODING_UTF8)
  end

  def download
    send_data(@resource_download.get_contents, filename: @resource_download.orig_filename)
  end

  def download_mo
    fname_idx = @resource_download.orig_filename.rindex('.')
    mo_fname = File.join(File.dirname(@resource_download.full_filename), "#{@resource_download.orig_filename[0...fname_idx]}.mo")

    if File.exist?(mo_fname)
      send_file(mo_fname)
    else
      set_err('file does not exist')
    end
  end

  def destroy
    @resource_upload.destroy
    flash[:notice] = _('Upload cancelled')
    redirect_to controller: :text_resources, action: :show, id: @text_resource.id
  end

  private

  def locate_parent
    begin
      @text_resource = TextResource.find(params[:text_resource_id].to_i)
    rescue
      set_err('Cannot locate this project')
      return false
    end
    if @user
      unless @user.can_view?(@text_resource)
        set_err('Not your project')
        return false
      end
    elsif @text_resource.is_public != 1
      set_err('Not a public project')
      return false
    end
  end

  def locate_download
    begin
      @resource_download = ResourceDownload.find(params[:id].to_i)
    rescue
      set_err('Cannot find this upload')
      return false
    end

    if @resource_download.text_resource != @text_resource
      set_err('This upload does not belong to the project')
      return false
    end
  end

  def verify_client
    unless @user.can_view?(@text_resource)
      set_err('You cannot access this page')
      false
    end
  end

  def verify_client_optional
    if @user
      verify_client
    else
      (@text_resource.is_public == 1)
    end
  end

  def setup_user_optional
    setup_user(false)
  end
end
