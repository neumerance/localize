class AddTxnIdWithUniqueIndexToAccountLine < ActiveRecord::Migration[5.0]
  def change
    add_column :account_lines, :txn_id, :string
    add_index :account_lines, [:account_type, :account_id, :txn_id], unique: true
  end
end
