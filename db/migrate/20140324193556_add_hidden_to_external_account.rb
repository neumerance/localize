class AddHiddenToExternalAccount < ActiveRecord::Migration
  def self.up
  	add_column :external_accounts, :hidden, :boolean, :default => false
  end

  def self.down
  	remove_column :external_accounts, :hidden
  end
end
