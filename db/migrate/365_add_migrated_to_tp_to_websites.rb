class AddMigratedToTpToWebsites < ActiveRecord::Migration
  def self.up
    add_column :websites, :migrated_to_tp, :boolean, :default => false
  end

  def self.down
    remove_column :websites, :migrated_to_tp
  end
end
