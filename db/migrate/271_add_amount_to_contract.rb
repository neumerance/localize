class AddAmountToContract < ActiveRecord::Migration
	def self.up
		add_column :website_translation_contracts, :amount, :decimal, {:precision=>8, :scale=>2, :default=>0}
		add_column :website_translation_contracts, :currency_id, :integer
	end

	def self.down
		remove_column :website_translation_contracts, :amount
		remove_column :website_translation_contracts, :currency_id
	end
end
