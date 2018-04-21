class AddAnonToUser < ActiveRecord::Migration
	def self.up
		add_column :users, :anon, :integer, :default=>0
	end

	def self.down
		remove_column :users, :anon
	end
end
