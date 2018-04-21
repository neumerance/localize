class AddImportedToResourceDownloadStat < ActiveRecord::Migration[5.0]
  def change
    add_column :resource_download_stats, :imported, :integer
  end
end
