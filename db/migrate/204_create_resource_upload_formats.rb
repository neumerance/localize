class CreateResourceUploadFormats < ActiveRecord::Migration
	def self.up
		create_table(:resource_upload_formats, :options => 'ENGINE=InnoDB DEFAULT CHARSET=utf8') do |t|
			t.column :resource_upload_id, :int
			t.column :resource_format_id, :int
		end
	end

	def self.down
		drop_table :resource_upload_formats
	end
end
