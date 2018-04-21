class AlertEmailsController < ApplicationController
  def create
    @alert_email = AlertEmail.new(
      translation_analytics_profile_id: params[:translation_analytics_profile_id],
      email: params[:email],
      enabled: (params[:enabled] == 'true' ? true : false),
      name: params[:name]
    )

    @alert_email.save
  end

  def destroy
    @alert_email = AlertEmail.find(params[:id])
    @alert_email.destroy
  end

  def update_enabled
    return unless params[:checked]
    alert_email = AlertEmail.find(params[:id])
    checked = params[:checked] == 'true' ? true : false

    alert_email.enabled = checked
    alert_email.save!
  end

end
