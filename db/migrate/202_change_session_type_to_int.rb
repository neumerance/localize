class ChangeSessionTypeToInt < ActiveRecord::Migration
	def self.up
		rename_column :user_sessions, :embedded, :display
	end

	def self.down
		rename_column :user_sessions, :display, :embedded
	end
end
