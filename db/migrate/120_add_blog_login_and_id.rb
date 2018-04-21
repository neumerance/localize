class AddBlogLoginAndId < ActiveRecord::Migration
	def self.up
		add_column :websites, :login, :string
		add_column :websites, :password, :string
		add_column :websites, :blogid, :integer
	end

	def self.down
		remove_column :websites, :login
		remove_column :websites, :password
		remove_column :websites, :blogid
	end
end
