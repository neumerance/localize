class ConvertXliffToUtf8Mb4 < ActiveRecord::Migration[5.0]
  def self.up
    execute 'ALTER TABLE `xliff_trans_units` CHANGE `source` `source` LONGTEXT CHARACTER SET utf8mb4 COLLATE utf8mb4_bin NULL DEFAULT NULL;'
    execute 'ALTER TABLE `xliff_trans_unit_mrks` CHANGE `content` `content` LONGTEXT CHARACTER SET utf8mb4 COLLATE utf8mb4_bin NULL DEFAULT NULL;'
  end
  def self.down
    execute 'ALTER TABLE `xliff_trans_units` CHANGE `source` `source` LONGTEXT CHARACTER SET utf8 COLLATE utf8_bin NULL DEFAULT NULL;'
    execute 'ALTER TABLE `xliff_trans_unit_mrks` CHANGE `content` `content` LONGTEXT CHARACTER SET utf8 COLLATE utf8_bin NULL DEFAULT NULL;'
  end
end
