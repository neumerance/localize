class CreateMoneyTransactions < ActiveRecord::Migration
	def self.up
		create_table(:money_transactions, :options => 'ENGINE=InnoDB DEFAULT CHARSET=utf8') do |t|
			# amount
			t.column :amount, :decimal, {:precision=>8, :scale=>2, :default=>0}
			t.column :fee_rate, :decimal, {:precision=>8, :scale=>2, :default=>0}
			t.column :fee, :decimal, {:precision=>8, :scale=>2, :default=>0}

			t.column :currency_id, :int
			
			# transfer information
			t.column :source_account_type, :string
			t.column :source_account_id, :int
			
			t.column :target_account_type, :string
			t.column :target_account_id, :int
			
			t.column :operation_code, :int
			t.column :status, :int
			t.column :chgtime, :datetime
			
			# optional - invoice that this transfer belongs to
			t.column :owner_type, :string
			t.column :owner_id, :int
		end
	end

	def self.down
		drop_table :money_transactions
	end
end
