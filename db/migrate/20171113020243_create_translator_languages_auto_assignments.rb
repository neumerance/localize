class CreateTranslatorLanguagesAutoAssignments < ActiveRecord::Migration[5.0]
  def change
    create_table :translator_languages_auto_assignments do |t|
      t.references :translator, foreign_key: {to_table: :users}
      t.integer :from_language_id, null: false
      t.integer :to_language_id, null: false
      t.decimal :min_price_per_word, precision: 4, scale: 2

      t.index [:translator_id, :from_language_id, :to_language_id], unique: true, name: 'translator_language_pair'
    end
  end
end