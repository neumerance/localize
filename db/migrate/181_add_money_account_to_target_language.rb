class AddMoneyAccountToTargetLanguage < ActiveRecord::Migration
	def self.up
		add_column :cms_target_languages, :money_account_id, :int
		add_column :cms_target_languages, :amount, :decimal, {:precision=>8, :scale=>2, :default=>0}
	end

	def self.down
		remove_column :cms_target_languages, :money_account_id
		remove_column :cms_target_languages, :amount
	end
end
