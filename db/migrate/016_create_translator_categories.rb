class CreateTranslatorCategories < ActiveRecord::Migration
  def self.up
    create_table(:translator_categories, :options => 'ENGINE=InnoDB DEFAULT CHARSET=utf8') do |t|
      t.column :translator_id, :int
      t.column :category_id, :int
    end
  end

  def self.down
    drop_table :translator_categories
  end
end
