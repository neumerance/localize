class AddUserSessionCounter < ActiveRecord::Migration
	def self.up
		add_column :user_sessions, :counter, :integer, :null => false, :default => 0
	end

	def self.down
		remove_column :user_sessions, :counter
	end
end
