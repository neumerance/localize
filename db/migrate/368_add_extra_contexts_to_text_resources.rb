class AddExtraContextsToTextResources < ActiveRecord::Migration
  def self.up
    add_column :text_resources, :extra_contexts, :text
  end

  def self.down
    remove_column :text_resources, :extra_contexts
  end
end
