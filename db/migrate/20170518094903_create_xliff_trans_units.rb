class CreateXliffTransUnits < ActiveRecord::Migration[5.0]
  def change
    create_table :xliff_trans_units, :options => 'ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci' do |t|
      t.integer :parsed_xliff_id
      t.string :trans_unit_id
      t.integer :source_language_id
      t.integer :target_language_id
      t.text :top_content
      t.text :bottom_content
      t.text :source, :limit => 4294967295
      t.timestamps
    end
  end
end
