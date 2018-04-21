class AddVatSupportToInvoices < ActiveRecord::Migration
  def self.up
    add_column :invoices, :tax_amount, :decimal, :precision => 8, :scale => 2, :default => 0.0
    add_column :invoices, :tax_rate, :decimal, :precision => 4, :scale => 2
    add_column :invoices, :tax_country_id, :integer
  end

  def self.down
    remove_columns :invoices, :tax_amount, :tax_rate, :tax_country_id
  end
end
