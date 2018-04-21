class AddExternalAccountUserDetails < ActiveRecord::Migration
	def self.up
		add_column :external_accounts, :fname, :string
		add_column :external_accounts, :lname, :string
		add_column :external_accounts, :verified, :integer, :default=>0
	end

	def self.down
		remove_column :external_accounts, :fname
		remove_column :external_accounts, :lname
		remove_column :external_accounts, :verified
	end
end
