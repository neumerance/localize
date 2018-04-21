class CreateTranslationSnapshot < ActiveRecord::Migration
	def self.up
		create_table( :translation_snapshots, :options => 'ENGINE=InnoDB DEFAULT CHARSET=utf8') do |t|
			t.integer :translation_analytics_language_pair_id

			t.datetime :date, :null => false
			t.integer :words_to_translate
			t.integer :translated_words

			t.integer :words_to_review
			t.integer :reviewed_words

			t.integer :total_issues
			t.integer :unresolved_issues

			t.timestamps
		end
	end

	def self.down
		drop_table :translation_snapshots
	end
end
