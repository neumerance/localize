class AddBouncedToWebDialogs < ActiveRecord::Migration
  def self.up
    add_column :web_dialogs, :bounced, :boolean, :default => false
  end

  def self.down
    remove_column :web_dialogs, :bounced
  end
end
