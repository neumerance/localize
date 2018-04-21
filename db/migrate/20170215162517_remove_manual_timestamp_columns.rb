class RemoveManualTimestampColumns < ActiveRecord::Migration[5.0]
  def change
    remove_column :websites, :mcat
    remove_column :websites, :muat
    remove_column :text_resources, :mcat
    remove_column :text_resources, :muat
  end
end
