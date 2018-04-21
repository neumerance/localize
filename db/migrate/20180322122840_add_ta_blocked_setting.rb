class AddTaBlockedSetting < ActiveRecord::Migration[5.0]
  def up
    add_column :users, :ta_blocked, :boolean, default: false
  end

  def down
    remove_column :users, :ta_blocked
  end
end
