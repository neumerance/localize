class AddMasterAccountToUsers < ActiveRecord::Migration
	def self.up
		add_column :users, :master_account_id, :integer
	end

	def self.down
		remove_column :users, :master_account_id
	end
end
