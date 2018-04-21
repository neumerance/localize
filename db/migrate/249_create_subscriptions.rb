class CreateSubscriptions < ActiveRecord::Migration
	def self.up
		create_table( :subscriptions, :options => 'ENGINE=InnoDB DEFAULT CHARSET=utf8') do |t|
			t.column :user_id, :integer
			
			t.column :owner_id, :integer
			t.column :owner_type, :string
			
			t.column :kind, :integer
			t.column :status, :integer
			
			t.column :amount, :decimal, {:precision=>8, :scale=>2, :default=>0}
			
			t.column :paid_date, :datetime
			t.column :expires_date, :datetime
			t.column :renew_duration, :integer
			t.timestamps
		end
	end

	def self.down
		drop_table :subscriptions
	end
end
