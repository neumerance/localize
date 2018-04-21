class AddRegisteredThroughWpmlToUsers < ActiveRecord::Migration[5.0]
  def change
    add_column :users, :registered_through_wpml, :boolean
  end
end
