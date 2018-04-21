class AddMoreUserDetails < ActiveRecord::Migration
	def self.up
		add_column :users, :company, :string
		add_column :users, :title, :string
		add_column :users, :url, :string
	end

	def self.down
		remove_column :users, :company
		remove_column :users, :title
		remove_column :users, :url
	end
end
