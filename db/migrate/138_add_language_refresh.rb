class AddLanguageRefresh < ActiveRecord::Migration
	def self.up
		add_column :users, :scanned_for_languages, :integer, :default=>0
		add_column :languages, :scanned_for_translators, :integer, :default=>0
	end

	def self.down
		remove_column :users, :scanned_for_languages
		remove_column :languages, :scanned_for_translators
	end
end
