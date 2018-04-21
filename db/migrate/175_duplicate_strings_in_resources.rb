class DuplicateStringsInResources < ActiveRecord::Migration
	def self.up
		add_column :resource_strings, :master_string_id, :integer
		add_column :text_resources, :ignore_duplicates, :integer, :default=>0
	end

	def self.down
		remove_column :resource_strings, :master_string_id
		remove_column :text_resources, :ignore_duplicates
	end
end
