class AddHoldToAccount < ActiveRecord::Migration
	def self.up
		add_column :money_accounts, :hold_sum, :decimal, {:precision=>8, :scale=>2, :default=>0}
	end

	def self.down
		remove_column :money_accounts, :hold_sum
	end
end
