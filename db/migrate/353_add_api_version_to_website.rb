class AddApiVersionToWebsite < ActiveRecord::Migration
  def self.up
    add_column :websites, :api_version, :string
  end

  def self.down
    remove_column :websites, :api_version
  end
end
