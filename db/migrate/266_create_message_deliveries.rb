class CreateMessageDeliveries < ActiveRecord::Migration
	def self.up
		create_table( :message_deliveries, :options => 'ENGINE=InnoDB DEFAULT CHARSET=utf8') do |t|
			t.column :message_id, :integer
			t.column :user_id, :integer
			t.timestamps
		end
		add_index :message_deliveries, [:message_id], :name=>'message', :unique=>false
		add_index :message_deliveries, [:user_id], :name=>'user', :unique=>false
	end

	def self.down
		drop_table :message_deliveries
	end
end
