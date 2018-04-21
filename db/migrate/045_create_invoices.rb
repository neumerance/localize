class CreateInvoices < ActiveRecord::Migration
	def self.up
		create_table( :invoices, :options => 'ENGINE=InnoDB DEFAULT CHARSET=utf8' ) do |t|
			t.column :kind, :int
			
			t.column :payment_processor, :int # selected payment processor
			
			# currency
			t.column :currency_id, :int

			# expected gross amount
			t.column :gross_amount, :decimal, {:precision=>8, :scale=>2, :default=>0}
			
			# received net amount
			t.column :net_amount, :decimal, {:precision=>8, :scale=>2, :default=>0}
			
			# PayPal transaction number
			t.column :txn, :string
			
			# transaction status
			t.column :status, :int
			
			t.column :create_time, :datetime
			t.column :modify_time, :datetime

			# payer information
			t.column :user_id, :int
			t.column :address_id, :int
		end
	end

	def self.down
		drop_table :invoices
	end
end
