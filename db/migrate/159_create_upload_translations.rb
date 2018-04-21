class CreateUploadTranslations < ActiveRecord::Migration
	def self.up
		create_table( :upload_translations, :options => 'ENGINE=InnoDB DEFAULT CHARSET=utf8') do |t|
			t.column :resource_upload_id, :int
			t.column :resource_download_id, :int
			t.column :language_id, :int
			
			t.timestamps
		end
	end

	def self.down
		drop_table :upload_translations
	end
end
