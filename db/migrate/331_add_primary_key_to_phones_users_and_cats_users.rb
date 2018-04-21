class AddPrimaryKeyToPhonesUsersAndCatsUsers < ActiveRecord::Migration
	def self.up
		add_column :phones_users, :id, :primary_key
		add_column :cats_users, :id, :primary_key
	end
	def self.down
		remove_column :phones_users, :id
		remove_column :cats_users, :id
	end
end

