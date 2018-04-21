class ChangeFieldsToBinaryToSaveNonUtf8CharsWhenProcessingXliff < ActiveRecord::Migration[5.0]
  def change
    change_column :xliff_trans_units, :source, :binary, limit: 5.megabyte
    change_column :xliff_trans_unit_mrks, :content, :binary, limit: 5.megabyte
  end
end
