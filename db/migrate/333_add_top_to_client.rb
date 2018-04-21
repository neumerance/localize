class AddTopToClient < ActiveRecord::Migration
	def self.up
		add_column :users, :top, :boolean
	end

	def self.down
		remove_column :users, :top
	end
end
