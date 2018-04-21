class CreateLanguagePairFixedPrices < ActiveRecord::Migration[5.0]
  def change
    create_table :language_pair_fixed_prices do |t|
      t.references :from_language, foreign_key: { to_table: :languages }
      t.references :to_language, foreign_key: { to_table: :languages }
      t.decimal :price, precision: 8, scale: 2
      t.timestamps
    end
    add_index :language_pair_fixed_prices,
              [:from_language_id, :to_language_id],
              name: 'language_pair',
              unique: true
  end
end
