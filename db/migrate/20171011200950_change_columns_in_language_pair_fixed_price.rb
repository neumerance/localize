class ChangeColumnsInLanguagePairFixedPrice < ActiveRecord::Migration[5.0]
  def change
    rename_column :language_pair_fixed_prices, :price, :calculated_price
    add_column :language_pair_fixed_prices, :actual_price, :decimal, precision: 8, scale: 2
  end
end
