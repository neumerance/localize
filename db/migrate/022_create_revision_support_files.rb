class CreateRevisionSupportFiles < ActiveRecord::Migration
  def self.up
    create_table(:revision_support_files, :options => 'ENGINE=InnoDB DEFAULT CHARSET=utf8') do |t|
		t.column :revision_id, :int
		t.column :support_file_id, :int
    end
  end

  def self.down
    drop_table :revision_support_files
  end
end
