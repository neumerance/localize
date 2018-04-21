class CreateUserToken < ActiveRecord::Migration[5.0]
  def self.up
    create_table :user_tokens do |t|
      t.integer :user_id
      t.string :token
      t.timestamps
    end
  end

  def self.down
    drop_table :user_tokens
  end
end
