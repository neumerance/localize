class AddBetaFlagToUsers < ActiveRecord::Migration[5.0]
  def self.up
    add_column :users, :beta_user, :boolean, default: false
  end

  def self.down
    remove_column :users, :beta_user
  end
end

