class AddProcessedFlagToCmsRequest < ActiveRecord::Migration[5.0]

  def self.up
    add_column :cms_requests, :xliff_processed, :boolean, default: false
  end

  def self.down
    remove_column :cms_requests, :xliff_processed
  end
end
