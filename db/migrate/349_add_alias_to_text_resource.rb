class AddAliasToTextResource < ActiveRecord::Migration
  def self.up
    add_column :text_resources, :alias_id, :integer
  end

  def self.down
    remove_column :text_resources, :alias_id
  end
end
