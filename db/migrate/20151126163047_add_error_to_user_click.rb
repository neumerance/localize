class AddErrorToUserClick < ActiveRecord::Migration
  def self.up
    add_column :user_clicks, :error, :string
    add_column :user_clicks, :log, :text
  end

  def self.down
    remove_column :user_clicks, :log
    remove_column :user_clicks, :error
  end
end
