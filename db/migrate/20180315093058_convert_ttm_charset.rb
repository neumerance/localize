class ConvertTtmCharset < ActiveRecord::Migration[5.0]
  def up
    ActiveRecord::Base.connection.execute "ALTER TABLE `translators_translation_memories` CHANGE `content` `content` LONGTEXT CHARACTER SET utf8mb4 COLLATE utf8mb4_bin NULL DEFAULT NULL;"
    ActiveRecord::Base.connection.execute "ALTER TABLE `translators_translation_memories` CHANGE `raw_content` `raw_content` LONGTEXT CHARACTER SET utf8mb4 COLLATE utf8mb4_bin NULL DEFAULT NULL;"
    ActiveRecord::Base.connection.execute "ALTER TABLE `translators_translated_memories` CHANGE `content` `content` LONGTEXT CHARACTER SET utf8mb4 COLLATE utf8mb4_bin NULL DEFAULT NULL;"
    ActiveRecord::Base.connection.execute "ALTER TABLE `translators_translated_memories` CHANGE `raw_content` `raw_content` LONGTEXT CHARACTER SET utf8mb4 COLLATE utf8mb4_bin NULL DEFAULT NULL;"
  end
end
