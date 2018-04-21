class AddResourceLanguageVersionNum < ActiveRecord::Migration
	def self.up
		add_column :resource_languages, :version_num, :int, :default=>0
		add_column :resource_stats, :resource_language_id, :int
		add_column :resource_stats, :resource_language_rev, :int
	end

	def self.down
		remove_column :resource_languages, :version_num
		remove_column :resource_stats, :resource_language_id
		remove_column :resource_stats, :resource_language_rev
	end
end
