class ConvertParseXliffToUtf8mb4 < ActiveRecord::Migration[5.0]
  def self.up
    execute 'ALTER TABLE `parsed_xliffs` CHANGE `raw_original` `raw_original` LONGTEXT CHARACTER SET utf8mb4 COLLATE utf8mb4_bin NULL DEFAULT NULL;'
    execute 'ALTER TABLE `parsed_xliffs` CHANGE `raw_parsed` `raw_parsed` LONGTEXT CHARACTER SET utf8mb4 COLLATE utf8mb4_bin NULL DEFAULT NULL;'
  end
  def self.down
    execute 'ALTER TABLE `parsed_xliffs` CHANGE `raw_original` `raw_original` LONGTEXT CHARACTER SET utf8 COLLATE utf8_bin NULL DEFAULT NULL;'
    execute 'ALTER TABLE `parsed_xliffs` CHANGE `raw_parsed` `raw_parsed` LONGTEXT CHARACTER SET utf8 COLLATE utf8_bin NULL DEFAULT NULL;'
  end
end
