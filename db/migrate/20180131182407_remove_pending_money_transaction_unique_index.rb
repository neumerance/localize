class RemovePendingMoneyTransactionUniqueIndex < ActiveRecord::Migration[5.0]
  def change
    remove_index :pending_money_transactions, column: [:owner_id, :owner_type]
  end
end
