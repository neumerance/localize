class IncreaseBalanceStorage < ActiveRecord::Migration
  def self.up
    change_column :money_accounts,  :balance,  :decimal,   :precision => 9, :scale => 2
    change_column :account_lines,   :balance,  :decimal,   :precision => 9, :scale => 2
  end

  def self.down
    change_column :money_accounts,  :balance,  :decimal,   :precision => 8, :scale => 2
    change_column :account_lines,   :balance,  :decimal,   :precision => 8, :scale => 2
  end
end
