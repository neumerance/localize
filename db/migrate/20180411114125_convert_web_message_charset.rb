class ConvertWebMessageCharset < ActiveRecord::Migration[5.0]
  def up
    ActiveRecord::Base.connection.execute "ALTER TABLE `web_messages` CHANGE `client_body` `client_body` LONGTEXT CHARACTER SET utf8mb4 COLLATE utf8mb4_bin NULL DEFAULT NULL;"
  end
end
