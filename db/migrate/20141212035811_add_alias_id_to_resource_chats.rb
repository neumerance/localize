class AddAliasIdToResourceChats < ActiveRecord::Migration
  def self.up
    add_column :resource_chats, :alias_id, :integer
  end

  def self.down
    remove_column :resource_chats, :alias_id
  end
end
