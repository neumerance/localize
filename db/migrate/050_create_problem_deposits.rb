class CreateProblemDeposits < ActiveRecord::Migration
	def self.up
		create_table( :problem_deposits, :options => 'ENGINE=InnoDB DEFAULT CHARSET=utf8') do |t|
			t.column :reason, :int
			t.column :txn, :string
			t.column :invoice_id, :int
			t.column :status, :int
			t.column :description, :text
		end
	end

	def self.down
		drop_table :problem_deposits
	end
end
