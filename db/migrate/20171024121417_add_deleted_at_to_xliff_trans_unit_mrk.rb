class AddDeletedAtToXliffTransUnitMrk < ActiveRecord::Migration[5.0]
  def change
    add_column :xliff_trans_unit_mrks, :deleted_at, :datetime
    add_index :xliff_trans_unit_mrks, :deleted_at
  end
end
