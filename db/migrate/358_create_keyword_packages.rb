class CreateKeywordPackages < ActiveRecord::Migration
  def self.up
    create_table(:keyword_packages, :option => 'ENGINE=InnoDB DEFAULT CHARSET=utf8') do |t|
      t.column :keywords_number, :integer, :null => false
      t.column :price, :decimal, {:precision => 8, :scale => 2, :null => false}
      t.column :comments, :text
      t.timestamps
    end

    KeywordPackage.create([
      {:keywords_number => 5, :price => 24.95, :comments => "5 USD per keyword"},
      {:keywords_number => 10, :price => 39.95, :comments => "4 USD per keyword"},
      {:keywords_number => 15, :price => 54.95, :comments => "3.66 USD per keyword"},
      {:keywords_number => 20, :price => 59.95, :comments => "3 USD per keyword"},
      {:keywords_number => 0, :price => 0, :comments => "Use previously purchased keywords"}
    ])
  end

  def self.down
    drop_table :keyword_packages
  end
end
