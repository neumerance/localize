class AddMoneyAccountWarningSignature < ActiveRecord::Migration
	def self.up
		add_column :money_accounts, :warning_signature, :string
	end

	def self.down
		remove_column :money_accounts, :warning_signature
	end
end
