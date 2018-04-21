class CreateTranslatorsTranslatedMemories < ActiveRecord::Migration[5.0]
  def up
    create_table :translators_translated_memories do |t|
      t.integer :language_id
      t.integer :translators_translation_memory_id
      t.integer :translator_id
      t.text    :content
      t.text    :raw_content
      t.integer :tm_status
      t.timestamps
    end
  end

  def down
    drop_table :translators_translated_memories
  end
end

