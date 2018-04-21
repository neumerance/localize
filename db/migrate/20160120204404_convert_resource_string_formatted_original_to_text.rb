class ConvertResourceStringFormattedOriginalToText < ActiveRecord::Migration
  def self.up
    change_column :resource_strings, :formatted_original, :text
    ResourceString.where(['formatted_original IS NOT ?', nil]).update_all(formatted_original: nil)
  end

  def self.down
    change_column :resource_strings, :formatted_original, :string
  end
end
