class AddRawTextToTranslationMemory < ActiveRecord::Migration[5.0]
  def self.up
    execute 'ALTER TABLE `translation_memories` ADD `raw_content` LONGTEXT CHARACTER SET utf8mb4 COLLATE utf8mb4_bin NULL DEFAULT NULL AFTER `content`;'
    execute 'ALTER TABLE `translation_memories` ADD `raw_signature` VARCHAR(255) CHARACTER SET utf8 COLLATE utf8_bin NULL DEFAULT NULL AFTER `signature`;'
    execute 'ALTER TABLE `translation_memories` CHANGE `content` `content` LONGTEXT CHARACTER SET utf8mb4 COLLATE utf8mb4_bin NULL DEFAULT NULL;'
  end

  def self.down
    remove_column :translation_memories, :raw_content
    remove_column :translation_memories, :raw_signature
    execute 'ALTER TABLE `translation_memories` CHANGE `content` `content` LONGTEXT CHARACTER SET utf8 COLLATE utf8_bin NULL DEFAULT NULL;'
  end
end
