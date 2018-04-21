require File.dirname(__FILE__) + '/../test_helper'

class TranslationAnalyticsLanguagePairTest < ActiveSupport::TestCase
  fixtures :translation_analytics_language_pairs, :translation_snapshots

  def test_deadline
    lp = translation_analytics_language_pairs(:lp1)
    assert_equal lp.deadline, lp.read_attribute(:deadline)

    lp = translation_analytics_language_pairs(:lp2)
    assert_equal lp.deadline, lp.project_completion
  end

  def test_estimate_rate
    lp = translation_analytics_language_pairs(:lp1)
    assert_equal lp.estimate_rate, lp.read_attribute(:estimate_time_rate)

    lp = translation_analytics_language_pairs(:lp2)
    assert_equal lp.estimate_rate, TranslationAnalyticsLanguagePair::DEFAULT_ESTIMATE_RATE
  end

  def test_auto_deadline?
    lp = translation_analytics_language_pairs(:lp1)
    assert_equal false, lp.auto_deadline?

    lp = translation_analytics_language_pairs(:lp2)
    assert_equal true, lp.auto_deadline?
  end

  def test_finished?
    lp = translation_analytics_language_pairs(:lp1)
    assert_equal false, lp.finished?

    lp = translation_analytics_language_pairs(:lp2)
    assert_equal true, lp.finished?
  end

  def test_project_completion
    lp = translation_analytics_language_pairs(:lp1)
    # time_rate = 99
    # 4000/10000 translated
    last_snapshot = lp.translation_snapshots.last
    assert_equal Date.today + 60.days, lp.project_completion
  end

end
