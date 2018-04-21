class RemoveWpmlFlowFromUserSession < ActiveRecord::Migration[5.0]
  def change
    remove_column :user_sessions, :wpml_flow, :string
  end
end
