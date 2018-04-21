class CreateAlertEmail < ActiveRecord::Migration 
	def self.up
		create_table( :alert_emails, :options => 'ENGINE=InnoDB DEFAULT CHARSET=utf8') do |t|
			t.integer :translation_analytics_profile_id
			t.boolean :enabled
			t.string :name
			t.string :email

			t.timestamps
		end
	end

	def self.down
		drop_table :alert_emails
	end
end
