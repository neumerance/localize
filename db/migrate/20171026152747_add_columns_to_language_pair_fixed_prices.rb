class AddColumnsToLanguagePairFixedPrices < ActiveRecord::Migration[5.0]
  def change
    add_column :language_pair_fixed_prices, :number_of_transactions, :bigint
    add_column :language_pair_fixed_prices, :calculated_price_last_year,
               :decimal, precision: 8, scale: 2
    add_column :language_pair_fixed_prices, :number_of_transactions_last_year,
               :bigint
  end
end
