class AddProjectType < ActiveRecord::Migration
	def self.up
		add_column :projects, :kind, :integer, :default=>TA_PROJECT
		add_column :revisions, :kind, :integer, :default=>TA_PROJECT
	end

	def self.down
		remove_column :projects, :kind
		remove_column :revisions, :kind
	end
end
