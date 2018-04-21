class AddTasFailedColumn < ActiveRecord::Migration[5.0]
  def change
    add_column :cms_requests, :tas_failed, :boolean, default: false
  end
end
