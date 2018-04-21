class AddUsedFlagToUserToken < ActiveRecord::Migration[5.0]

  def self.up
    add_column :user_tokens, :used, :boolean, default: false
  end

  def self.down
    remove_column :user_tokens, :used
  end

end
