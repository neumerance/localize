class AddVatNumberToInvoices < ActiveRecord::Migration
  def self.up
    add_column :invoices, :vat_number, :string
  end

  def self.down
    remove_column :invoices, :vat_number
  end
end
