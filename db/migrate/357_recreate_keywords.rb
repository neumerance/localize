class RecreateKeywords < ActiveRecord::Migration
  def self.up
    drop_table :keywords if ActiveRecord::Base.connection.table_exists? 'keywords'
    create_table(:keywords, :option => 'ENGINE=InnoDB DEFAULT CHARSET=utf8') do |t|
      t.column :purchased_keyword_package_id, :integer
      t.column :text, :string
      t.column :status, :integer, :default => 0
      t.column :result, :text
      t.timestamps
    end
  end

  def self.down
    drop_table :keywords
  end
end
