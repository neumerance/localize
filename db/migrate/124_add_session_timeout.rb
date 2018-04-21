class AddSessionTimeout < ActiveRecord::Migration
	def self.up
		add_column :user_sessions, :long_life, :integer
	end

	def self.down
		remove_column :user_sessions, :long_life
	end
end
