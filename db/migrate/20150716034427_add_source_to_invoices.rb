class AddSourceToInvoices < ActiveRecord::Migration
  def self.up
    change_table :invoices do |t|
      t.references :source, :polymorphic => true
    end
  end

  def self.down
    change_table :invoices do |t|
      t.remove_references :imageable, :polymorphic => true
    end
  end
end
