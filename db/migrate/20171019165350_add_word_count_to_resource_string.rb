class AddWordCountToResourceString < ActiveRecord::Migration[5.0]
  def change
    add_column :resource_strings, :word_count, :integer
  end
end
