class AddPrivateId < ActiveRecord::Migration
	def self.up
		add_column :projects, :private_key, :integer
		add_column :revisions, :private_key, :integer
	end

	def self.down
		remove_column :projects, :private_key
		remove_column :revisions, :private_key
	end
end
