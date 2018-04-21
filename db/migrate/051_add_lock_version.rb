class AddLockVersion < ActiveRecord::Migration
	def self.up
		add_column :money_accounts, :lock_version, :integer, :default => 0
		add_column :money_transactions, :lock_version, :integer, :default => 0
		add_column :invoices, :lock_version, :integer, :default => 0
		add_column :bids, :lock_version, :integer, :default => 0
	end

	def self.down
		remove_column :money_accounts, :lock_version
		remove_column :money_transactions, :lock_version
		remove_column :invoices, :lock_version
		remove_column :bids, :lock_version
	end
end
