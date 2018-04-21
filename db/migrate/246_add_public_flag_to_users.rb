class AddPublicFlagToUsers < ActiveRecord::Migration
	def self.up
		add_column :users, :is_public, :integer
	end

	def self.down
		remove_column :users, :is_public
	end
end
