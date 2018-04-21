class CreateTranslationMemories < ActiveRecord::Migration[5.0]
  def change
    create_table :translation_memories, :options => 'ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci' do |t|
      t.integer :client_id
      t.integer :language_id
      t.string :signature, index: true
      t.text :content
      t.timestamps
    end
  end
end
