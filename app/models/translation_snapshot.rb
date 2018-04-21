class TranslationSnapshot < ApplicationRecord
  belongs_to :translation_analytics_language_pair
  has_one :translation_analytics_profile, through: :translation_analytics_language_pair

  after_create :send_alerts

  def untranslated_words
    words_to_translate - translated_words
  end

  def profile
    translation_analytics_profile
  end

  def language_pair
    translation_analytics_language_pair
  end

  def neighbor_snapshots
    language_pair.translation_snapshots.order('id ASC')
  end

  def translation_complete
    words_to_translate == translated_words
  end

  def review_complete
    words_to_review == reviewed_words
  end

  def translator_rate_test
    if date + profile.missed_estimated_deadline_days.days >= language_pair.deadline
      remaining_words = words_to_translate - translated_words
      remaining_days = Date.today - language_pair.deadline
      remaining_words.to_f / remaining_days.to_f < language_pair.translator_rate
    else
      false
    end
  end

  def no_progress_test
    language_pair.days_with_no_progress > profile.no_translation_progress_days
  end

  private

  def send_alerts
    return false if profile.project.client.anon == 1

    unless translation_complete
      if profile.no_translation_progress_alert && no_progress_test
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
        track_campaing(profile, language_pair.from_language, language_pair.to_language, :no_progress)
      end

      if profile.missed_estimated_deadline_alert && translator_rate_test
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
        track_campaing(profile, language_pair.from_language, language_pair.to_language, :missed_deadline)
      end
    end
  end

  def missed_deadline
    (date >= language_pair.deadline) && words_to_translate > translated_words
  end

  def track_campaing(profile, from_language, to_language, source)
    campaing_track = CampaingTrack.where(["campaing_id = ? and
                                      from_language_id = ? and to_language_id = ? and
                                      project_type = ? and project_id = ?",
                                          2, from_language.id, to_language.id,
                                          profile.project_type, profile.project_id]).first

    if campaing_track
      campaing_track.extra_info[source] += 1
    else
      campaing_track = CampaingTrack.new
      campaing_track.from_language = from_language
      campaing_track.to_language = to_language
      campaing_track.campaing_id = 1
      campaing_track.project = profile.project
      campaing_track.extra_info = if source == :no_progress
                                    { no_progress: 1, missed_deadline: 0 }
                                  else
                                    { no_progress: 0, missed_deadline: 1 }
                                  end
      campaing_track.extra_info[:from_language_id] = from_language.id
      campaing_track.extra_info[:to_language_id] = to_language.id

      campaing_track.state = 0
    end
    campaing_track.save!
  end

end
