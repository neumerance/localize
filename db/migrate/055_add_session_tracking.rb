class AddSessionTracking < ActiveRecord::Migration
	def self.up
		add_column :user_sessions, :tracked, :integer, :default => 0
	end

	def self.down
		remove_column :user_sessions, :tracked
	end
end
