class AddContainerToCmsRequest < ActiveRecord::Migration
	def self.up
		add_column :cms_requests, :container, :string
		add_index :cms_requests, [:website_id, :container], :name=>'container', :unique=>false
	end

	def self.down
		remove_index :cms_requests, :name=>'container'
		remove_column :cms_requests, :container
	end
end
