class CreateXliffTransUnitMrks < ActiveRecord::Migration[5.0]
  def change
    create_table :xliff_trans_unit_mrks, :options => 'ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci' do |t|
      t.integer :xliff_trans_unit_id
      t.integer :mrk_type
      t.integer :mrk_id
      t.string :trans_unit_id
      t.integer :language_id
      t.integer :translations_status
      t.string :top_content
      t.string :bottom_content, default: '</mrk>'
      t.text :content
      t.integer :translation_memory_id
      t.integer :translated_memory_id, default: nil
      t.timestamps
    end
  end
end
