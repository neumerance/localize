class RemoveFieldsForAutoAssignmentOnUsers < ActiveRecord::Migration[5.0]
  def change
    remove_column :users, :autoassign_translation, :boolean, null: false, default: false
    remove_column :users, :autoassign_review, :boolean, null: false, default: false
    remove_column :users, :min_price_per_word, :decimal, precision: 4, scale: 2
  end
end
