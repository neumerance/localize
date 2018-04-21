class AddZipCodeToUsers < ActiveRecord::Migration
  def self.up
    add_column :users, :zip_code, :string, {:after => :country_id}
  end

  def self.down
    remove_column :users, :zip_code
  end
end