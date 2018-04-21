class CreateCmsSaves < ActiveRecord::Migration[5.0]

  def self.up
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

  def self.down
    drop_table :cms_saves
  end
end
