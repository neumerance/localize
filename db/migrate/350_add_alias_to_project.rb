class AddAliasToProject < ActiveRecord::Migration
  def self.up
    add_column :projects, :alias_id, :integer
  end

  def self.down
    remove_column :projects, :alias_id
  end
end
