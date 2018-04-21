class AddBlockingCms < ActiveRecord::Migration[5.0]
  def change
    add_column :cms_requests, :blocked_cms_request_id, :integer, default: nil
    add_index :cms_requests, :blocked_cms_request_id
  end
end
