class AddWebsiteIdToInvoices < ActiveRecord::Migration
  def self.up
    add_column :invoices, :website_id, :integer, :default => nil
  end

  def self.down
    remove_column :invoices, :website_id
  end
end
