class AddTaLimitToUsers < ActiveRecord::Migration
  def self.up
    add_column :users, :ta_limit, :integer, :default => 50
  end

  def self.down
    remove_column :users, :ta_limit
  end
end
