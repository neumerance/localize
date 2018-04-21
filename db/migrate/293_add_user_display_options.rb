class AddUserDisplayOptions < ActiveRecord::Migration
	def self.up
		add_column :users, :display_options, :integer, :default=>0
	end

	def self.down
		remove_column :users, :display_options
	end
end
