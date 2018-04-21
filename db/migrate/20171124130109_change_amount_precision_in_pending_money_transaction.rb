class ChangeAmountPrecisionInPendingMoneyTransaction < ActiveRecord::Migration[5.0]
  def change
    change_column :pending_money_transactions, :amount, :decimal, precision: 8, scale: 2
  end
end
