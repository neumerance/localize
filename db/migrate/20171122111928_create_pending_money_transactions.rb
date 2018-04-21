class CreatePendingMoneyTransactions < ActiveRecord::Migration[5.0]
  def change
    create_table :pending_money_transactions do |t|
      t.integer :owner_id, index: true
      t.string :owner_type
      t.integer :money_account_id, index: true
      t.decimal :amount, precision: 4, scale: 2
      t.timestamps
    end
  end
end
