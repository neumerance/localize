class CreateMassPaymentReceipts < ActiveRecord::Migration
	def self.up
		create_table( :mass_payment_receipts, :options => 'ENGINE=InnoDB DEFAULT CHARSET=utf8') do |t|
			t.column :withdrawal_id, :string

			t.column :txn, :string
			t.column :fee, :decimal, {:precision=>8, :scale=>2, :default=>0}
			t.column :status, :int
			t.column :chgtime, :datetime
		end
	end

	def self.down
		drop_table :mass_payment_receipts
	end
end
