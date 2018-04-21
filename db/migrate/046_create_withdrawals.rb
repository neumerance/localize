class CreateWithdrawals < ActiveRecord::Migration
	def self.up
		create_table( :withdrawals, :options => 'ENGINE=InnoDB DEFAULT CHARSET=utf8' ) do |t|
			t.column :submit_time, :datetime
		end
	end

	def self.down
		drop_table :withdrawals
	end
end
