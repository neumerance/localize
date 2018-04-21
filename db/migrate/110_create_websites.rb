class CreateWebsites < ActiveRecord::Migration
	def self.up
		create_table( :websites, :options => 'ENGINE=InnoDB DEFAULT CHARSET=utf8') do |t|
			t.column :client_id, :int
			t.column :name, :string
			t.column :description, :text
			t.column :platform_kind, :int
			t.column :platform_version, :int
			t.column :url, :string
			
			t.timestamps
		end
	end

	def self.down
		drop_table :websites
	end
end
