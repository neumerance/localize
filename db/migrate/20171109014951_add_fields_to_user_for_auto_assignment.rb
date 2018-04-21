class AddFieldsToUserForAutoAssignment < ActiveRecord::Migration[5.0]
  def change
    add_column :users, :autoassign_translation, :boolean, null: false, default: false
    add_column :users, :autoassign_review, :boolean, null: false, default: false
    add_column :users, :min_price_per_word, :decimal, precision: 4, scale: 2
  end
end
