class AddSourceToTm < ActiveRecord::Migration[5.0]
  def change
    add_column :translated_memories, :tm_status, :integer, size: 1, default: 0
  end
end
