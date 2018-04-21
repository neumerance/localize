class AddCmsIdToCmsRequests < ActiveRecord::Migration
	def self.up
		add_column :cms_requests, :cms_id, :string
		add_index :cms_requests, [:website_id, :cms_id], :name=>'website_cms_id', :unique=>false
	end

	def self.down
		remove_index :cms_requests, :name=>'website_cms_id'
		remove_column :cms_requests, :cms_id
	end
end
