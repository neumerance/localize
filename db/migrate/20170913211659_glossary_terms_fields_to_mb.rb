class GlossaryTermsFieldsToMb < ActiveRecord::Migration[5.0]
  def change
    execute "ALTER TABLE `glossary_terms` CHANGE `txt` `txt` VARCHAR(255)  CHARACTER SET utf8mb4  NULL  DEFAULT NULL;"
    execute "ALTER TABLE `glossary_terms` CHANGE `description` `description` VARCHAR(255)  CHARACTER SET utf8mb4  NULL  DEFAULT NULL;"
    execute "ALTER TABLE `glossary_translations` CHANGE `txt` `txt` VARCHAR(255)  CHARACTER SET utf8mb4  NULL  DEFAULT NULL;"
  end
end
