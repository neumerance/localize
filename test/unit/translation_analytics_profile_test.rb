require File.dirname(__FILE__) + '/../test_helper'

class TranslationAnalyticsLanguagePairTest < ActiveSupport::TestCase
  def test_create
    website = Website.first
    a = TranslationAnalyticsProfile.new
    a.project = website
    assert a.save
    assert_equal 1, a.alert_emails.size
    assert_equal a.alert_emails.first.email, website.client.email
    assert_equal a.alert_emails.first.name, website.client.fname
  end
end
