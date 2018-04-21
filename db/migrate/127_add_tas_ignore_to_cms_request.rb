class AddTasIgnoreToCmsRequest < ActiveRecord::Migration
	def self.up
		add_column :cms_requests, :tas_url, :string
		add_column :cms_requests, :tas_port, :integer
	end

	def self.down
		remove_column :cms_requests, :tas_url
		remove_column :cms_requests, :tas_port
	end
end
