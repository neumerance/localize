class CreateLanguagePairField < ActiveRecord::Migration[5.0]
  def self.up
    add_column :language_pair_fixed_prices, :language_pair_id, :string, default: nil
    add_index :language_pair_fixed_prices, :language_pair_id, unique: true
    add_column :translator_languages_auto_assignments, :language_pair_id, :string, default: nil
    add_index :translator_languages_auto_assignments, :language_pair_id, unique: false
    execute "UPDATE language_pair_fixed_prices SET language_pair_id=CONCAT_WS('_', from_language_id, to_language_id)"
    execute "UPDATE translator_languages_auto_assignments SET language_pair_id=CONCAT_WS('_', from_language_id, to_language_id)"
  end

  def self.down
    remove_column :language_pair_fixed_prices, :language_pair_id
    remove_column :translator_languages_auto_assignments, :language_pair_id
  end
end
