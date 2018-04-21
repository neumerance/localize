class CreateDownloads < ActiveRecord::Migration
	def self.up
		create_table( :downloads, :options => 'ENGINE=InnoDB DEFAULT CHARSET=utf8') do |t|
			# acts as attachment fields
			t.column :content_type, :string
			t.column :filename, :string     
			t.column :size, :integer
			t.column :parent_id,  :integer 
			t.column :width, :integer  
			t.column :height, :integer

			# my fields
			t.column :create_time, :datetime
			t.column :generic_name, :string
			t.column :major_version, :int
			t.column :sub_version, :int
			t.column :notes, :string
		end
	end

	def self.down
		drop_table :downloads
	end
end
