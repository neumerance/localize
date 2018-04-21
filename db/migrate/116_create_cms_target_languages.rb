class CreateCmsTargetLanguages < ActiveRecord::Migration
	def self.up
		create_table( :cms_target_languages, :options => 'ENGINE=InnoDB DEFAULT CHARSET=utf8') do |t|
			t.column :cms_request_id, :int
			t.column :language_id, :int
			t.column :status, :int
			t.column :lock_version, :int, :default=>0

			t.timestamps
		end
	end

	def self.down
		drop_table :cms_target_languages
	end
end
