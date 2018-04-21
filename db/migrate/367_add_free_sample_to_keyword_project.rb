class AddFreeSampleToKeywordProject < ActiveRecord::Migration
  def self.up
    add_column :keyword_projects, :free_sample, :bool, :default => false
  end

  def self.down
    remove_column :keyword_projects, :free_sample
  end
end
