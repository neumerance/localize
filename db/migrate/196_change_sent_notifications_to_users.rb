class ChangeSentNotificationsToUsers < ActiveRecord::Migration
	def self.up
		rename_column :sent_notifications, :translator_id, :user_id
		add_column :sent_notifications, :code, :integer
	end

	def self.down
		rename_column :sent_notifications, :user_id, :translator_id
		remove_column :sent_notifications, :code
	end
end
