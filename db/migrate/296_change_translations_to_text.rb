class ChangeTranslationsToText < ActiveRecord::Migration
	def self.up
		change_column :db_content_translations, :txt, :text
	end

	def self.down
		change_column :db_content_translations, :txt, :string
	end
end
