class CreateTempDownloads < ActiveRecord::Migration
	def self.up
		create_table( :temp_downloads, :options => 'ENGINE=InnoDB DEFAULT CHARSET=utf8') do |t|
			t.column :user_id, :int
			t.column :title, :string
			t.column :description, :string
			t.column :body, :text
			t.timestamps
		end
	end

	def self.down
		drop_table :temp_downloads
	end
end
