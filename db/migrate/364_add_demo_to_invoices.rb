class AddDemoToInvoices < ActiveRecord::Migration
  def self.up
    add_column :invoices, :demo, :boolean
  end

  def self.down
    remove_column :invoices, :demo
  end
end
