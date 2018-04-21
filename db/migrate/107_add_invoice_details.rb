class AddInvoiceDetails < ActiveRecord::Migration
	def self.up
		add_column :invoices, :company, :string
	end

	def self.down
		remove_column :invoices, :company
	end
end
