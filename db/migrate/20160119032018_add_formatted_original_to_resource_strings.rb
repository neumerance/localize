class AddFormattedOriginalToResourceStrings < ActiveRecord::Migration
  def self.up
    add_column :resource_strings, :formatted_original, :string
  end

  def self.down
    remove_column :resource_strings, :formatted_original
  end
end
