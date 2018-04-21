class TranslationAnalyticsProfilesController < TranslationAnalyticsBaseController
  prepend_before_action :from_cms
  prepend_before_action :setup_user
  layout :determine_layout

  def test_emails
    return unless %w(sandbox development).include? Rails.env
    profile = TranslationAnalyticsProfile.find(params[:id])
    language_pair = profile.translation_analytics_language_pairs.last

    raise 'Missing lnguage_pair' if language_pair.nil?

    profile.alert_emails.each do |alert_email|
      next unless alert_email.can_receive_emails?
      ReminderMailer.no_translation_progress(
        alert_email.name,
        alert_email.email,
        profile.project,
        language_pair.from_language,
        language_pair.to_language,
        language_pair.days_with_no_progress
      ).deliver_now
    end

    profile.alert_emails.each do |alert_email|
      next unless alert_email.can_receive_emails?
      ReminderMailer.missed_translation_deadline(
        alert_email.name,
        alert_email.email,
        profile.project,
        language_pair.from_language,
        language_pair.to_language,
        language_pair.deadline,
        language_pair.estimated_completion_date
      ).deliver_now
    end

    redirect_to :back
  end

  def edit
    raise 'Invalid project type' unless %w(Website TextResource Revision).include?(params[:project_type])

    @translation_analytics_profile = TranslationAnalyticsProfile.find(params[:id])
    @project = @translation_analytics_profile.project
    @project_type = @project.class.to_s
    @project_id = @project.id

    if params[:auto_setup] && !@translation_analytics_profile.configured
      @translation_analytics_profile.missed_estimated_deadline_alert = true
      @translation_analytics_profile.missed_estimated_deadline_days = 5
      @translation_analytics_profile.no_translation_progress_alert = true
      @translation_analytics_profile.no_translation_progress_days = 7
    end

    raise "You can't do this" unless @user.has_supporter_privileges? || (@translation_analytics_profile.project.client == @user)

    @selected_tab = :alerts
    @layout = 'wpml' if params[:from_cms] == '0'

    render layout: @layout
  end

  def update
    @translation_analytics_profile = TranslationAnalyticsProfile.find(params[:id])
    project = @translation_analytics_profile.project
    params[:translation_analytics_profile][:configured] = 1
    respond_to do |format|
      if @translation_analytics_profile.update_attributes(params[:translation_analytics_profile])
        format.html { redirect_to(:back, notice: _('configuration successfully updated.')) }
      else

        format.html { render action: 'edit', layout: @layout }
      end
    end
  end

  def new_email_table_line
    @profile_id = params[:profile_id]
    render layout: false
  end
end
