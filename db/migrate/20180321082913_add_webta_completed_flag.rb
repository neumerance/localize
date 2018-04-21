class AddWebtaCompletedFlag < ActiveRecord::Migration[5.0]
  def change
    add_column :cms_requests, :webta_completed, :boolean, default: false
    add_column :cms_requests, :webta_parent_completed, :boolean, default: false
    add_column :cms_requests, :ta_tool_parent_completed, :boolean, default: false
  end
end
