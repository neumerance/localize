class AdjustTranslationAnalyticsColumns < ActiveRecord::Migration
	def self.up
		add_column :translation_analytics_profiles, :no_translation_progress_alert, :bool, :default => true
		add_column :translation_analytics_profiles, :no_translation_progress_days, :integer, :default => 3
		add_column :translation_analytics_profiles,  :missed_estimated_deadline_days, :integer, :default => 3

    # This column already exists, but let's remove it and add it again to set the default and assure no other user
    # has the old data.
	  remove_column :translation_analytics_profiles, :missed_estimated_deadline_alert
	  add_column :translation_analytics_profiles, :missed_estimated_deadline_alert, :bool, :default => true

    # These should not be used anymore
		remove_column :translation_analytics_profiles, :translation_under_estimated_time_alert
		remove_column :translation_analytics_profiles, :translation_under_estimated_time_threshold
	end

	def self.down
		remove_column :translation_analytics_profiles, :no_translation_progress_alert
		remove_column :translation_analytics_profiles, :no_translation_progress_days
		remove_column :translation_analytics_profiles,  :missed_estimated_deadline_days

		add_column :translation_analytics_profiles, :translation_under_estimated_time_alert, :bool
		add_column :translation_analytics_profiles, :translation_under_estimated_time_threshold, :integer
	end
end
