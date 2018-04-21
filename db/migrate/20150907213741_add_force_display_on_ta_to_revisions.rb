class AddForceDisplayOnTaToRevisions < ActiveRecord::Migration
  def self.up
    add_column :revisions, :force_display_on_ta, :boolean
  end

  def self.down
    remove_column :revisions, :force_display_on_ta
  end
end
