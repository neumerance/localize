class CreateCmsRequests < ActiveRecord::Migration
	def self.up
		create_table( :cms_requests, :options => 'ENGINE=InnoDB DEFAULT CHARSET=utf8') do |t|
			t.column :website_id, :int
			t.column :status, :int
			t.timestamps
		end
	end

	def self.down
		drop_table :cms_requests
	end
end
