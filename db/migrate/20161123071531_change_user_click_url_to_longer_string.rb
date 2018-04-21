class ChangeUserClickUrlToLongerString < ActiveRecord::Migration
  def self.up
    change_column :user_clicks, :url, :text
  end

  def self.down
    change_column :user_clicks, :url, :string
  end
end
