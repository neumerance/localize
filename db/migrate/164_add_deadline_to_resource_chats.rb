class AddDeadlineToResourceChats < ActiveRecord::Migration
	def self.up
		add_column :resource_chats, :deadline, :datetime
	end

	def self.down
		remove_column :resource_chats, :deadline
	end
end
