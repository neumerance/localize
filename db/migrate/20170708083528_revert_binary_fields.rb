class RevertBinaryFields < ActiveRecord::Migration[5.0]
  def self.up
    change_column :xliff_trans_units, :source, "LONGTEXT CHARACTER SET utf8 COLLATE utf8_bin"
    change_column :xliff_trans_unit_mrks, :content, "LONGTEXT CHARACTER SET utf8 COLLATE utf8_bin"
    change_column :parsed_xliffs, :raw_parsed, "LONGTEXT CHARACTER SET utf8 COLLATE utf8_bin"
    change_column :parsed_xliffs, :raw_original, "LONGTEXT CHARACTER SET utf8 COLLATE utf8_bin"
    change_column :translation_memories, :content, "LONGTEXT CHARACTER SET utf8 COLLATE utf8_bin"
    change_column :translated_memories, :content, "LONGTEXT CHARACTER SET utf8 COLLATE utf8_bin"
  end
  def self.down
    change_column :xliff_trans_units, :source, :binary, limit: 5.megabyte
    change_column :xliff_trans_unit_mrks, :content, :binary, limit: 5.megabyte
    change_column :parsed_xliffs, :raw_original, :binary, limit: 5.megabyte
    change_column :parsed_xliffs, :raw_parsed, :binary, limit: 5.megabyte
    change_column :translation_memories, :content, :binary, limit: 5.megabyte
    change_column :translated_memories, :content, :binary, limit: 5.megabyte
  end
end
