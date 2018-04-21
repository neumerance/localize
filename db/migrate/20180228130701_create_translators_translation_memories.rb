class CreateTranslatorsTranslationMemories < ActiveRecord::Migration[5.0]
  def up
    create_table :translators_translation_memories do |t|
      t.integer :translator_id
      t.integer :language_id
      t.string  :signature
      t.string  :raw_signature
      t.text    :content
      t.text    :raw_content
      t.integer :word_count
      t.timestamps
    end
  end

  def down
    drop_table :translators_translation_memories
  end
end
