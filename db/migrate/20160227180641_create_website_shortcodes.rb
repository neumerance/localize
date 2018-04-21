class CreateWebsiteShortcodes < ActiveRecord::Migration
  def self.up
    create_table :website_shortcodes do |t|
      t.references :website
      t.references :shortcode
      t.boolean :enabled
    end
  end

  def self.down
    drop_table :website_shortcodes
  end
end
