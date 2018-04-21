class ChangeTxtToLongTextOnResourceStringAndStringTranslations < ActiveRecord::Migration
  def self.up
    change_column :resource_strings, :txt, :text, :limit => 200000
    change_column :string_translations, :txt, :text, :limit => 200000
  end

  def self.down
    change_column :resource_strings, :txt, :text, :limit => 65535
    change_column :string_translations, :txt, :text, :limit => 65535
  end
end
