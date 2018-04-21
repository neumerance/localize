require File.dirname(__FILE__) + '/../test_helper'

class TranslationSnapshotTest < ActiveSupport::TestCase
  fixtures :translation_analytics_language_pairs, :translation_snapshots,
           :translation_analytics_profiles, :languages, :alert_emails

  def test_send_no_progress_alerts
    # Should send an e-mail if no progress is done according to the configuration

    # Goes without progress for all acceptable days
    lp = translation_analytics_language_pairs(:lp1)
    profile = lp.translation_analytics_profile
    (profile.no_translation_progress_days - 1).times do
      snapshot = lp.translation_snapshots.last.dup
      snapshot.date = snapshot.date + 1.day
      assert_difference('ActionMailer::Base.deliveries.length', 0) do
        snapshot.save!
      end
    end

    # No progress in the limit day
    snapshot = lp.translation_snapshots.last.dup
    snapshot.date = snapshot.date + 1.day
    assert_difference('ActionMailer::Base.deliveries.length', 2) do
      snapshot.save!
    end

    # Then should be notified once per day
    snapshot = lp.translation_snapshots.last.dup
    snapshot.date = snapshot.date + 1.day
    assert_difference('ActionMailer::Base.deliveries.length', 2) do
      snapshot.save!
    end
  end

  def test_honor_no_progress_alert_alarm_false
    # Should never send an e-mail if the alarm is disabled
    lp = translation_analytics_language_pairs(:lp2)
    profile = lp.translation_analytics_profile
    (profile.no_translation_progress_days * 10).times do # A lot of times
      snapshot = lp.translation_snapshots.last.dup
      snapshot.date = snapshot.date + 1.day
      assert_difference('ActionMailer::Base.deliveries.length', 0) do
        snapshot.save!
      end
    end
  end

  def test_send_missing_deadline_alert
    # Should receive miss deadline alert as configured
    lp = translation_analytics_language_pairs(:lp1)
    profile = lp.translation_analytics_profile

    # Don't alert in this snapshot because it is not in the 3 day range
    snapshot = lp.translation_snapshots.last.dup
    snapshot.date = snapshot.date + 1.day
    snapshot.translated_words += lp.estimate_rate
    assert_difference('ActionMailer::Base.deliveries.length', 0) do
      snapshot.save!
    end

    # Next one alert
    snapshot = lp.translation_snapshots.last.dup
    snapshot.date = snapshot.date + 1.day
    snapshot.translated_words += lp.estimate_rate
    assert_difference('ActionMailer::Base.deliveries.length', 2) do
      snapshot.save!
    end

    # And every one afterwards alert too
    snapshot = lp.translation_snapshots.last.dup
    snapshot.date = snapshot.date + 1.day
    snapshot.translated_words += lp.estimate_rate
    assert_difference('ActionMailer::Base.deliveries.length', 2) do
      snapshot.save!
    end
  end

  def test_honor_missed_estimated_deadline_alert_false
    # Should never send an e-mail if the alarm is disable
    lp = translation_analytics_language_pairs(:lp2)
    profile = lp.translation_analytics_profile

    10.times do # a big enough number here, according to fixtures
      snapshot = lp.translation_snapshots.last.dup
      snapshot.date = snapshot.date + 1.day
      snapshot.translated_words += lp.estimate_rate
      assert_difference('ActionMailer::Base.deliveries.length', 0) do
        snapshot.save!
      end
    end
  end

end
