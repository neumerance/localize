class AddClientToManagedWork < ActiveRecord::Migration
	def self.up
		add_column :managed_works, :client_id, :integer
	end

	def self.down
		remove_column :managed_works, :client_id
	end
end
