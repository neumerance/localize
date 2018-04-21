class AddSubscriptionToInvoice < ActiveRecord::Migration
	def self.up
		add_column :invoices, :subscription_id, :integer
	end

	def self.down
		remove_column :invoices, :subscription_id
	end
end
