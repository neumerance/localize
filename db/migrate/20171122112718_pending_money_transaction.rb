class PendingMoneyTransaction < ActiveRecord::Migration[5.0]
  def change
    add_column :pending_money_transactions, :deleted_at, :datetime, default: nil, index: true
    add_index :pending_money_transactions, [:owner_id, :owner_type], :unique => true
  end
end
