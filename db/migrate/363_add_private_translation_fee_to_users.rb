class AddPrivateTranslationFeeToUsers < ActiveRecord::Migration
  def self.up
    add_column :users, :private_translation_fee, :float, :default => nil
  end

  def self.down
    remove_column :users, :private_translation_fee
  end
end
