class MoveCmsRequestToRevision < ActiveRecord::Migration
	def self.up
		add_column :revisions, :cms_request_id, :integer
		remove_column :projects, :cms_request_id
	end

	def self.down
		add_column :projects, :cms_request_id, :integer
		remove_column :revisions, :cms_request_id
	end
end
