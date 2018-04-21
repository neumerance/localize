class AddTranslatorToCmsTargetLanguage < ActiveRecord::Migration
	def self.up
		add_column :cms_target_languages, :translator_id, :int
	end

	def self.down
		remove_column :cms_target_languages, :translator_id
	end
end
