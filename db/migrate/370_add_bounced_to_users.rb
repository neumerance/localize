class AddBouncedToUsers < ActiveRecord::Migration
  def self.up
    add_column :users, :bounced, :boolean, :default => false
  end

  def self.down
    remove_column :users, :bounced
  end
end
