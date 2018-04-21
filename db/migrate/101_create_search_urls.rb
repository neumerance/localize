class CreateSearchUrls < ActiveRecord::Migration
	def self.up
		create_table( :search_urls, :options => 'ENGINE=InnoDB DEFAULT CHARSET=utf8') do |t|
			t.column :search_engine_id, :int
			t.column :language_id, :int
			t.column :url, :string
		end
	end

	def self.down
		drop_table :search_urls
	end
end
