class AddSkipInstantTranslationMailToUsers < ActiveRecord::Migration
  def self.up
    add_column :users, :skip_instant_translation_email, :boolean, :default => false
  end

  def self.down
    remove_column :users, :skip_instant_translation_email
  end
end
