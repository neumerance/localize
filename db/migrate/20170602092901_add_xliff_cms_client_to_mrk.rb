class AddXliffCmsClientToMrk < ActiveRecord::Migration[5.0]

  def self.up
    add_column :xliff_trans_unit_mrks, :xliff_id, :integer
    add_column :xliff_trans_unit_mrks, :cms_request_id, :integer
    add_column :xliff_trans_unit_mrks, :client_id, :integer
  end

  def self.down
    remove_column :xliff_trans_unit_mrks, :xliff_id
    remove_column :xliff_trans_unit_mrks, :cms_request_id
    remove_column :xliff_trans_unit_mrks, :client_id
  end

end
