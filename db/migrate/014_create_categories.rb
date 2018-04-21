class CreateCategories < ActiveRecord::Migration
  def self.up
    create_table(:categories, :options => 'ENGINE=InnoDB DEFAULT CHARSET=utf8') do |t|
      t.column :parent_id, :int
      t.column :name, :string
      t.column :description, :text
    end
  end

  def self.down
    drop_table :categories
  end
end
