class CreateReminders < ActiveRecord::Migration
	def self.up
		create_table(:reminders, :options => 'ENGINE=InnoDB DEFAULT CHARSET=utf8') do |t|
			t.column :normal_user_id, :int
			t.column :owner_id, :int
			t.column :owner_type, :string		
			t.column :event, :int
			t.column :expiration, :datetime
		end
	end

	def self.down
		drop_table :reminders
	end
end
