class AddIndexToTranslationMemory < ActiveRecord::Migration[5.0]
  def change
    add_index :translated_memories, :translation_memory_id
  end
end
