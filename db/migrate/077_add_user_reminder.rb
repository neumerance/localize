class AddUserReminder < ActiveRecord::Migration
	def self.up
		add_column :users, :signup_date, :datetime
		add_column :users, :sent_messages, :integer, :default=>0
	end

	def self.down
		remove_column :users, :signup_date
		remove_column :users, :sent_messages
	end
end
