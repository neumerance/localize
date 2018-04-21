class AddWebsiteToProject < ActiveRecord::Migration
	def self.up
		add_column :projects, :cms_request_id, :integer
	end

	def self.down
		remove_column :projects, :cms_request_id
	end
end
