class AddHashPasswordToUsers < ActiveRecord::Migration
  def self.up
    add_column :users, :hash_password, :string
  end

  def self.down
    remove_column :users, :hash_password
  end

  # Todo remove password column
end
