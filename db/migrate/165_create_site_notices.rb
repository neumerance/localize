class CreateSiteNotices < ActiveRecord::Migration
	def self.up
		create_table( :site_notices, :options => 'ENGINE=InnoDB DEFAULT CHARSET=utf8') do |t|
			t.integer :active
			t.datetime :start_time
			t.datetime :end_time
			t.text :txt

			t.timestamps
		end
	end

	def self.down
		drop_table :site_notices
	end
end
