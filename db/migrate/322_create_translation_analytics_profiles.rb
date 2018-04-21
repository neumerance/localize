class CreateTranslationAnalyticsProfiles < ActiveRecord::Migration
	def self.up
		create_table( :translation_analytics_profiles , :options => 'ENGINE=InnoDB DEFAULT CHARSET=utf8') do |t|
			t.integer :project_id, :null => false
			t.string :project_type, :null => false, :limit => 32

			t.column :missed_estimated_deadline_alert, :bool
			t.column :translation_under_estimated_time_alert, :bool
			t.column :translation_under_estimated_time_threshold, :integer
		end
	end

	def self.down
		drop_table :translation_analytics_profiles
	end
end
