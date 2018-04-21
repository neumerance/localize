class CreateKeywordTranslations < ActiveRecord::Migration
  def self.up
    create_table(:keyword_translations, :option => 'ENGINE=InnoDB DEFAULT CHARSET=utf8') do |t|
      t.column :keyword_id, :integer
      t.column :text, :string
      t.column :category, :integer
      t.column :hits, :integer
      t.timestamps
    end
  end

  def self.down
    drop_table :keyword_translations
  end
end
