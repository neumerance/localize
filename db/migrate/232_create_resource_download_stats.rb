class CreateResourceDownloadStats < ActiveRecord::Migration
	def self.up
		create_table( :resource_download_stats, :options => 'ENGINE=InnoDB DEFAULT CHARSET=utf8') do |t|
			t.integer :resource_download_id
			t.integer :total
			t.integer :completed
			t.timestamps
		end
		add_index :resource_download_stats, [:resource_download_id], :name=>'parent', :unique => false
	end

	def self.down
		drop_table :resource_download_stats
	end
end
