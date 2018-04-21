class TranslationAnalyticsProfile < ApplicationRecord
  belongs_to :project, polymorphic: true
  has_many :translation_analytics_language_pairs, dependent: :destroy
  has_many :translation_snapshots, through: :translation_analytics_language_pairs
  has_many :alert_emails

  after_create :add_default_email

  def add_default_email
    alert_email = AlertEmail.new(
      translation_analytics_profile_id: id,
      email: project.client.email,
      enabled: true,
      name: project.client.fname
    )
    alert_emails << alert_email
  end

  def add_language_pair(from_language, to_language)
    TranslationAnalyticsLanguagePair.transaction do
      language_pair = TranslationAnalyticsLanguagePair.create
      language_pair.to_language = to_language
      language_pair.from_language = from_language
      language_pair.translation_snapshots = []
      language_pair.save!
      translation_analytics_language_pairs << language_pair
      language_pair
    end
  end
end
