class AddDummyToWebsites < ActiveRecord::Migration
  def self.up
    add_column :websites, :dummy, :boolean, :default => false
  end

  def self.down
    remove_column :websites, :dummy
  end
end
