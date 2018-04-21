class CreateAccountLines < ActiveRecord::Migration
	def self.up
		create_table(:account_lines, :options => 'ENGINE=InnoDB DEFAULT CHARSET=utf8') do |t|
			t.column :account_id, :int
			t.column :account_type, :string
			
			t.column :chgtime, :datetime
			t.column :balance, :decimal, {:precision=>8, :scale=>2, :default=>0}
			t.column :money_transaction_id, :int
		end
	end

	def self.down
		drop_table :account_lines
	end
end
