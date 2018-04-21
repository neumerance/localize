class AddUserNotifications < ActiveRecord::Migration
	def self.up
		add_column :users, :notifications, :integer
	end

	def self.down
		remove_column :users, :notifications
	end
end
