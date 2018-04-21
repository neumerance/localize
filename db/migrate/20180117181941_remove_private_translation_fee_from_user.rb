class RemovePrivateTranslationFeeFromUser < ActiveRecord::Migration[5.0]
  def change
    remove_column :users, :private_translation_fee, :string
  end
end
