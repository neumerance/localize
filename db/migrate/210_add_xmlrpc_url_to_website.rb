class AddXmlrpcUrlToWebsite < ActiveRecord::Migration
	def self.up
		add_column :websites, :xmlrpc_path, :string
	end

	def self.down
		remove_column :websites, :xmlrpc_path
	end
end
