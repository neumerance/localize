class CreateRevisionCategories < ActiveRecord::Migration
  def self.up
    create_table(:revision_categories, :options => 'ENGINE=InnoDB DEFAULT CHARSET=utf8') do |t|
      t.column :revision_id, :int
      t.column :category_id, :int
    end
  end

  def self.down
    drop_table :revision_categories
  end
end
