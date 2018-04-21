class AddListToCmsRequest < ActiveRecord::Migration
	def self.up
		add_column :cms_requests, :list_type, :string
		add_column :cms_requests, :list_id, :integer
		add_index :cms_requests, [:website_id, :list_type, :list_id], :name=>'listitems'
	end

	def self.down
		remove_index :cms_requests, :name=>'listitems'
		remove_column :cms_requests, :list_type
		remove_column :cms_requests, :list_id
	end
end
