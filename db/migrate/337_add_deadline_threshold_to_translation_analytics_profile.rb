class AddDeadlineThresholdToTranslationAnalyticsProfile < ActiveRecord::Migration
	def self.up
		add_column :translation_analytics_profiles, :deadline_threshold, :integer,{:default => 0, :null => false}
	end

	def self.down
		remove_column :translation_analytics_profiles, :deadline_threshold
	end
end
