class TranslationAnalyticsBaseController < ApplicationController

  protected

  def get_project
    project_type =
      case params[:project_type]
      when 'Website'
        Website
      when 'TextResource'
        TextResource
      when 'Revision'
        Revision
      else
        raise 'Invalid project type'
      end

    project_type.find(params[:project_id])
  end

  def from_cms
    if @user.anon == 1
      redirect_to(controller: 'login', action: 'login_or_create_account', translation_analytics: 1, wid: params[:wid], accesskey: params[:accesskey])
      return
    end
    @from_cms = params[:from_cms] && !params[:from_cms].empty?
    @layout = @from_cms ? 'empty' : nil
  end
end
