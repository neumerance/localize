class CreateParsedXliffs < ActiveRecord::Migration[5.0]
  def change
    create_table :parsed_xliffs, :options => 'ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci' do |t|
      t.integer :xliff_id
      t.integer :client_id
      t.integer :cms_request_id
      t.integer :website_id
      t.integer :source_language_id
      t.integer :target_language_id
      t.text :raw_original, :limit => 4294967295
      t.text :raw_parsed, :limit => 4294967295
      t.text :top_content
      t.text :bottom_content
      t.text :header, :limit => 4294967295
      t.timestamps
    end
  end
end