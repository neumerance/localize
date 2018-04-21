class AddStatusToResourceLanguages < ActiveRecord::Migration
	def self.up
		add_column :resource_languages, :status, :integer, :default=>RESOURCE_LANGUAGE_OPEN
	end

	def self.down
		remove_column :resource_languages, :status
	end
end
