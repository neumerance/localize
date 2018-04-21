class AddWordCountToParsedXliff < ActiveRecord::Migration[5.0]
  def up
    add_column :parsed_xliffs, :word_count, :integer, default: 0
    add_column :parsed_xliffs, :tm_word_count, :integer, default: 0
  end

  def down
    remove_column :parsed_xliffs, :word_count, :integer
    remove_column :parsed_xliffs, :tm_word_count, :integer
  end
end
