class AddAllowFlagToLanguagesPairs < ActiveRecord::Migration[5.0]
  def change
    add_column :language_pair_fixed_prices, :published, :boolean, default: false
  end
end
