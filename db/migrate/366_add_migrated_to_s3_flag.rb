class AddMigratedToS3Flag < ActiveRecord::Migration
  def self.up
    [:images, :attachments, :downloads, :web_attachments, :xliffs, :zipped_files].each do |model|
      add_column model, :backup_on_s3, :boolean, :default => false
      add_index model, [:backup_on_s3], :name => 'backup_on_s3_idx', :unique => false
    end
  end

  def self.down
    [:images, :attachments, :downloads, :web_attachments, :xliffs, :zipped_files].each do |model|
      remove_index model, :name => 'backup_on_s3_idx'
      remove_column model, :backup_on_s3
    end
  end
end
