class AddWordCountToTm < ActiveRecord::Migration[5.0]
  def self.up
    add_column :translation_memories, :word_count, :integer, default: false
  end

  def self.down
    remove_column :translation_memories, :word_count
  end
end
