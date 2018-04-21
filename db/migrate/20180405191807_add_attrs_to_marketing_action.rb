class AddAttrsToMarketingAction < ActiveRecord::Migration[5.0]
  def change
    add_column :marketing_actions, :active_trail_contact_id, :integer
    add_column :marketing_actions, :cta_button_link, :string
    rename_table :marketing_actions, :active_trail_actions
  end
end
