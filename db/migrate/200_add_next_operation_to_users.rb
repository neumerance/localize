class AddNextOperationToUsers < ActiveRecord::Migration
	def self.up
		add_column :users, :next_operation, :string
	end

	def self.down
		remove_column :users, :next_operation
	end
end
