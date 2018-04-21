class CreateUserDownloads < ActiveRecord::Migration
	def self.up
		create_table(:user_downloads, :options => 'ENGINE=InnoDB DEFAULT CHARSET=utf8') do |t|
			t.column :user_id, :int
			t.column :download_id, :int
			t.column :download_time, :datetime
		end
	end

	def self.down
		drop_table :user_downloads
	end
end
