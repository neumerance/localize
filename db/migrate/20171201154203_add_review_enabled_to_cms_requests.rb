class AddReviewEnabledToCmsRequests < ActiveRecord::Migration[5.0]
  def change
    add_column :cms_requests, :review_enabled, :boolean
  end
end
