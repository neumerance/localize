class AddReviewTypeInManagedWork < ActiveRecord::Migration[5.0]
  def self.up
    add_column :managed_works, :review_type, :integer
  end

  def self.down
    remove_column :managed_works, :review_type
  end
end
