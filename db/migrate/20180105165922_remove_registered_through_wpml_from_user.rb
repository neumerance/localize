class RemoveRegisteredThroughWpmlFromUser < ActiveRecord::Migration[5.0]
  def change
    remove_column :users, :registered_through_wpml, :string
  end
end
