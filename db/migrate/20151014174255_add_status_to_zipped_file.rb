class AddStatusToZippedFile < ActiveRecord::Migration
  def self.up
    add_column :zipped_files, :status, :integer, {:default => 0}
    ResourceUpload.update_all 'status = 1'
  end

  def self.down
    remove_column :zipped_files, :status
  end
end
