class AddAllowedToWithdrawToUsers < ActiveRecord::Migration
  def self.up
    add_column :users, :allowed_to_withdraw, :boolean
  end

  def self.down
    remove_column :users, :allowed_to_withdraw
  end
end
