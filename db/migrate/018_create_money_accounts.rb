class CreateMoneyAccounts < ActiveRecord::Migration
	def self.up
		create_table(:money_accounts, :options => 'ENGINE=InnoDB DEFAULT CHARSET=utf8') do |t|
			# class type identifier
			t.column :type, :string	# the type is only used to identify user/bid accounts

			t.column :balance, :decimal, {:precision=>8, :scale=>2, :default=>0}
			t.column :currency_id, :int
			t.column :owner_id, :int
		end
	end

	def self.down
		drop_table :money_accounts
	end
end
