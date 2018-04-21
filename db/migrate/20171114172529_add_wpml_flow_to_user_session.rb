class AddWpmlFlowToUserSession < ActiveRecord::Migration[5.0]
  def change
    add_column :user_sessions, :wpml_flow, :boolean
  end
end
