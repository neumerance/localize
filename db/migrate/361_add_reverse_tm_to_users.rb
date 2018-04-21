class AddReverseTmToUsers < ActiveRecord::Migration
  def self.up
    add_column :users, :reverse_tm, :boolean, :default => false
  end

  def self.down
    remove_column :users, :reverse_tm
  end
end
