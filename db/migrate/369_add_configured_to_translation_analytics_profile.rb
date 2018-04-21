class AddConfiguredToTranslationAnalyticsProfile < ActiveRecord::Migration
  def self.up
    add_column :translation_analytics_profiles, :configured, :boolean, :default => false
    TranslationAnalyticsProfile.all.each do |tap|
      if tap.missed_estimated_deadline_alert || tap.no_translation_progress_alert
        tap.update_attribute :configured, true
      end
    end
  end

  def self.down
    remove_column :translation_analytics_profiles, :configured
  end
end
