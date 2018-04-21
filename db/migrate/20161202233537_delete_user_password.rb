class DeleteUserPassword < ActiveRecord::Migration[5.0]
  def self.up
    User.backup_and_delete_clear_text_password
    remove_column :users, :password
  end

  def self.down
    add_column :users, :password, :string
  end
end