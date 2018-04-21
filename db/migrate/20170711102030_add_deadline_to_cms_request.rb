class AddDeadlineToCmsRequest < ActiveRecord::Migration[5.0]
  def change
    add_column :cms_requests, :deadline, :datetime, default: nil
  end
end
