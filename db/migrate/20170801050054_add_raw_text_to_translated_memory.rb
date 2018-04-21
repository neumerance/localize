class AddRawTextToTranslatedMemory < ActiveRecord::Migration[5.0]
  def self.up
    execute 'ALTER TABLE `translated_memories` ADD `raw_content` TEXT CHARACTER SET utf8mb4 COLLATE utf8mb4_bin NULL DEFAULT NULL AFTER `content`;'
    execute 'ALTER TABLE `translated_memories` CHANGE `content` `content` TEXT CHARACTER SET utf8mb4 COLLATE utf8mb4_bin NULL DEFAULT NULL;'
  end
  def self.down
    remove_column :translated_memories, :raw_content
    execute 'ALTER TABLE `translated_memories` CHANGE `content` `content` TEXT CHARACTER SET utf8 COLLATE utf8_bin NULL DEFAULT NULL;'
  end
end
