class AddMoreIndexes < ActiveRecord::Migration[5.0]
  def self.up
    execute "ALTER TABLE `parsed_xliffs` ADD INDEX(`xliff_id`);"
    execute "ALTER TABLE `parsed_xliffs` ADD INDEX(`client_id`);"
    execute "ALTER TABLE `parsed_xliffs` ADD INDEX(`source_language_id`);"
    execute "ALTER TABLE `parsed_xliffs` ADD INDEX(`target_language_id`);"

    execute "ALTER TABLE `xliff_trans_units` ADD INDEX(`parsed_xliff_id`);"
    execute "ALTER TABLE `xliff_trans_units` ADD INDEX(`source_language_id`);"
    execute "ALTER TABLE `xliff_trans_units` ADD INDEX(`target_language_id`);"

    execute "ALTER TABLE `xliff_trans_unit_mrks` ADD INDEX(`language_id`);"
    execute "ALTER TABLE `xliff_trans_unit_mrks` ADD INDEX(`translation_memory_id`);"
    execute "ALTER TABLE `xliff_trans_unit_mrks` ADD INDEX(`translated_memory_id`);"
    execute "ALTER TABLE `xliff_trans_unit_mrks` ADD INDEX(`source_id`);"
    execute "ALTER TABLE `xliff_trans_unit_mrks` ADD INDEX(`target_id`);"
    execute "ALTER TABLE `xliff_trans_unit_mrks` ADD INDEX(`client_id`);"
    execute "ALTER TABLE `xliff_trans_unit_mrks` ADD INDEX(`xliff_id`);"
    execute "ALTER TABLE `xliff_trans_unit_mrks` ADD INDEX(`cms_request_id`);"

  end

  def self.down
    execute "ALTER TABLE parsed_xliffs DROP INDEX xliff_id;"
    execute "ALTER TABLE parsed_xliffs DROP INDEX client_id;"
    execute "ALTER TABLE parsed_xliffs DROP INDEX source_language_id;"
    execute "ALTER TABLE parsed_xliffs DROP INDEX target_language_id;"

    execute "ALTER TABLE xliff_trans_units DROP INDEX parsed_xliff_id;"
    execute "ALTER TABLE xliff_trans_units DROP INDEX source_language_id;"
    execute "ALTER TABLE xliff_trans_units DROP INDEX target_language_id;"

    execute "ALTER TABLE xliff_trans_unit_mrks DROP INDEX language_id;"
    execute "ALTER TABLE xliff_trans_unit_mrks DROP INDEX translation_memory_id;"
    execute "ALTER TABLE xliff_trans_unit_mrks DROP INDEX translated_memory_id;"
    execute "ALTER TABLE xliff_trans_unit_mrks DROP INDEX source_id;"
    execute "ALTER TABLE xliff_trans_unit_mrks DROP INDEX target_id;"
    execute "ALTER TABLE xliff_trans_unit_mrks DROP INDEX client_id;"
    execute "ALTER TABLE xliff_trans_unit_mrks DROP INDEX xliff_id;"
    execute "ALTER TABLE xliff_trans_unit_mrks DROP INDEX cms_request_id;"
  end
end
