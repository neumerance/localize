class CreateShortcodes < ActiveRecord::Migration
  def self.up
    create_table :shortcodes do |t|
      t.string :shortcode
      t.references :website
      t.boolean :enabled, :default => true
      t.string :content_type
      t.string :comment
      t.integer :created_by

      t.timestamps
    end

    add_index "shortcodes", ["shortcode", "website_id"], :name => "websites_shortcodes_unique", :unique => true
    add_index "shortcodes", ["website_id"], :name => "websites_shortcodes"
  end

  def self.down
    drop_table :shortcodes
  end
end
