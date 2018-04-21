class AddProjectKindToWebsites < ActiveRecord::Migration
	def self.up
		add_column :websites, :project_kind, :integer, :default=>PRODUCTION_CMS_WEBSITE
	end

	def self.down
		remove_column :websites, :project_kind
	end
end
