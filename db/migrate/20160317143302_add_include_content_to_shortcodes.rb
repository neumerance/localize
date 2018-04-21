class AddIncludeContentToShortcodes < ActiveRecord::Migration
  def self.up
    add_column :shortcodes, :include_content, :boolean, :default => true
  end

  def self.down
    remove_column :shortcodes, :include_content
  end
end
