class AddStatusSourceTargetToMrk < ActiveRecord::Migration[5.0]

  def self.up
    add_column :xliff_trans_unit_mrks, :mrk_status, :integer, default: 0
    add_column :xliff_trans_unit_mrks, :source_id, :integer, default: nil
    add_column :xliff_trans_unit_mrks, :target_id, :integer, default: nil
    remove_column :xliff_trans_unit_mrks, :translations_status
  end

  def self.down
    remove_column :xliff_trans_unit_mrks, :mrk_status
    remove_column :xliff_trans_unit_mrks, :source_id
    remove_column :xliff_trans_unit_mrks, :target_id
    add_column :xliff_trans_unit_mrks, :translations_status, :integer, default: nil
  end

end
