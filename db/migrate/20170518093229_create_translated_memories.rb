class CreateTranslatedMemories < ActiveRecord::Migration[5.0]
  def change
    create_table :translated_memories, :options => 'ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci' do |t|
      t.integer :client_id
      t.integer :language_id
      t.integer :translation_memory_id
      t.integer :translator_id
      t.text :content
      t.timestamps
    end
  end
end
