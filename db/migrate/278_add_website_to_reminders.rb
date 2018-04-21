class AddWebsiteToReminders < ActiveRecord::Migration
	def self.up
		add_column :reminders, :website_id, :string
		add_index :reminders, [:website_id], :name=>'website_id', :unique=>false
	end

	def self.down
		remove_index :reminders, :name=>'website_id'
		remove_column :reminders, :website_id
	end
end
