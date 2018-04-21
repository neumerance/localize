class AddXmlPathToResourceFormat < ActiveRecord::Migration
	def self.up
		add_column :resource_formats, :kind, :integer, :default=>RESOURCE_FORMAT_TEXT
	end

	def self.down
		remove_column :resource_formats, :kind
	end
end
