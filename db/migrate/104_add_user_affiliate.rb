class AddUserAffiliate < ActiveRecord::Migration
	def self.up
		add_column :users, :affiliate_id, :integer
		add_column :money_transactions, :affiliate_account_id, :integer
	end

	def self.down
		remove_column :users, :affiliate_id
		remove_column :money_transactions, :affiliate_account_id
	end
end
