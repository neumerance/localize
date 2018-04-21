class CompanyController < ApplicationController
  prepend_before_action :verify_client
  prepend_before_action :setup_user

  def new_language
    from_language = Language.find(params[:from_language_id])
    to_language = Language.find(params[:to_language_id])
    @website = @user.websites.find(params[:wid])

    # Update campaing track
    profile = @website.translation_analytics_profile
    campaing_track = CampaingTrack.where(campaing_id: 1, from_language_id: from_language.id, to_language_id: to_language.id, project_type: profile.project_type, project_id: profile.project_id)
    if campaing_track
      campaing_track.state = 1 if campaing_track.state == 0
      campaing_track.save
    end

    @language = Language.find(params[:to_language_id])
    @translators = if Rails.env == 'production'
                     User.find(19418, 367, 2670, 487)
                   else
                     Translator.all.take(4)
                   end
    @offer = @website.find_or_create_offer(from_language, to_language)
  end
end
