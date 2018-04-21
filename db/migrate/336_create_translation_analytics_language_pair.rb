class CreateTranslationAnalyticsLanguagePair < ActiveRecord::Migration
	def self.up
		create_table( :translation_analytics_language_pairs, :options => 'ENGINE=InnoDB DEFAULT CHARSET=utf8') do |t|
			t.integer :translation_analytics_profile_id
			t.integer :to_language_id
			t.integer :from_language_id
			t.integer :estimate_time_rate
			t.date :deadline
		end
	end

	def self.down
		drop_table :translation_analytics_language_pairs
	end
end
