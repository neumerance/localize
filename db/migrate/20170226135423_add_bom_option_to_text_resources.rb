class AddBomOptionToTextResources < ActiveRecord::Migration[5.0]

  def self.up
    add_column :text_resources, :add_bom, :boolean, default: false
  end

  def self.down
    remove_column :text_resources, :add_bom
  end

end
