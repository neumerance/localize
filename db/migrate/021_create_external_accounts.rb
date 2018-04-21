class CreateExternalAccounts < ActiveRecord::Migration
	def self.up
		create_table(:external_accounts, :options => 'ENGINE=InnoDB DEFAULT CHARSET=utf8') do |t|
			t.column :owner_id, :int
			
			# for external account - processor information
			t.column :external_account_type, :int
			t.column :status, :string
			t.column :identifier, :string
			t.column :address_id, :int
		end
		add_index :external_accounts, [:external_account_type, :identifier], :name=>'account_key', :unique => true
	end

	def self.down
		drop_table :external_accounts
	end
end
