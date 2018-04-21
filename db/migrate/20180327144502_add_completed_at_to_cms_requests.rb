class AddCompletedAtToCmsRequests < ActiveRecord::Migration[5.0]
  def up
    add_column :cms_requests, :completed_at, :datetime
  end

  def down
    remove_column :cms_requests, :completed_at
  end
end
