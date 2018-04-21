class AddWordCountToMrk < ActiveRecord::Migration[5.0]
  def up
    add_column :xliff_trans_unit_mrks, :word_count, :integer, default: 0
    add_column :xliff_trans_unit_mrks, :tm_word_count, :integer, default: 0
  end

  def down
    remove_column :xliff_trans_unit_mrks, :word_count, :integer
    remove_column :xliff_trans_unit_mrks, :tm_word_count, :integer
  end
end
