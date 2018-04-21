class CreatePurchasedKeywordPackages < ActiveRecord::Migration
  def self.up
    create_table(:purchased_keyword_packages, :option => 'ENGINE=InnoDB DEFAULT CHARSET=utf8') do |t|
      t.column :keyword_package_id, :integer, :null => false
      t.column :keyword_project_id, :integer, :null => false
      t.column :price, :decimal, {:precision => 8, :scale => 2, :null => false}
      t.column :remaining_keywords, :integer, :null => false
      t.timestamps
    end
  end

  def self.down
    drop_table :purchased_keyword_packages
  end
end
