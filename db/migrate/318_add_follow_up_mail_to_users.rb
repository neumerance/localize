class AddFollowUpMailToUsers < ActiveRecord::Migration
	def self.up
		add_column :users, :follow_up_email, :boolean
	end

	def self.down
		add_column :users, :follow_up_email
	end
end
