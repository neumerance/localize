class AddCountMethodRatioToLanguage < ActiveRecord::Migration[5.0]
  def up
    add_column :languages, :count_method, :string, default: 'words'
    add_column :languages, :ratio, :decimal, precision: 8, scale: 2, default: 1
  end

  def down
    remove_column :languages, :count_method, :string
    remove_column :languages, :ratio, :decimal
  end
end
