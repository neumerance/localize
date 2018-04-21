class AddWebsitePickup < ActiveRecord::Migration
	def self.up
		add_column :websites, :pickup_type, :integer, :default=>PICKUP_BY_RPC_POST
	end

	def self.down
		remove_column :websites, :pickup_type
	end
end
