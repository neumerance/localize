class AddBatchCountToCmsRequest < ActiveRecord::Migration[5.0]
  def change
    add_column :cms_requests, :batch_count, :integer, default: 0
    add_column :cms_requests, :batch_id, :integer, default: nil, index: true
  end
end
