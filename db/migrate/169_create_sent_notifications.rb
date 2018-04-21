class CreateSentNotifications < ActiveRecord::Migration
	def self.up
		create_table( :sent_notifications, :options => 'ENGINE=InnoDB DEFAULT CHARSET=utf8') do |t|
			t.column :owner_type, :string
			t.column :owner_id, :int
			
			t.column :translator_id, :int
			
			t.timestamps
		end
		add_index :sent_notifications, [:owner_type, :owner_id], :name=>'notification_owner'
	end

	def self.down
		drop_table :sent_notifications
	end
end
