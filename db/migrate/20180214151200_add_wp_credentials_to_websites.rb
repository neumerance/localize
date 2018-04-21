class AddWpCredentialsToWebsites < ActiveRecord::Migration[5.0]

  def self.up
    add_column :websites, :encrypted_wp_username, :string
    add_column :websites, :encrypted_wp_password, :string
    add_column :websites, :wp_login_url, :string
  end

  def self.down
    remove_column :websites, :encrypted_wp_username
    remove_column :websites, :encrypted_wp_password
    remove_column :websites, :wp_login_url
  end

end
  