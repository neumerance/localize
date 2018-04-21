class AddSupporterPasswordToUsers < ActiveRecord::Migration[5.0]

  def self.up
    add_column :users, :supporter_password, :string, default: nil
    add_column :users, :supporter_password_expiration, :datetime, default: nil
  end

  def self.down
    remove_column :users, :supporter_password
    remove_column :users, :supporter_password_expiration
  end

end
