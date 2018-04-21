class SetCorrectCharSetForTextResource < ActiveRecord::Migration[5.0]
  def up
    change_column :text_resources, :description, "LONGTEXT CHARACTER SET utf8mb4 COLLATE utf8mb4_bin"
  end
end
