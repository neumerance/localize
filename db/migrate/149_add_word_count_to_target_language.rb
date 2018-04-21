class AddWordCountToTargetLanguage < ActiveRecord::Migration
	def self.up
		add_column :cms_target_languages, :word_count, :integer
	end

	def self.down
		remove_column :cms_target_languages, :word_count
	end
end
