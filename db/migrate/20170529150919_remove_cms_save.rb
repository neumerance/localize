class RemoveCmsSave < ActiveRecord::Migration[5.0]
  def self.up
    drop_table :cms_saves
  end

  def self.down
    create_table :cms_saves do |t|
      t.integer :cms_request_id
      t.integer :xliff_id
      t.integer :source_language_id
      t.integer :target_language_id
      t.integer :translator_id
      t.integer :client_id
      t.text :body, limit: 16.megabytes
      t.timestamps
    end
  end
end
