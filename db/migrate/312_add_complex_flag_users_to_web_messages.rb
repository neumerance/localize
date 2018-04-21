class AddComplexFlagUsersToWebMessages< ActiveRecord::Migration
	def self.up
		add_column :web_messages, :complex_flag_users, :text
	end

	def self.down
		remove_column :web_messages, :complex_flag_users
	end
end
