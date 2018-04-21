class CreateImages < ActiveRecord::Migration
	def self.up
		create_table( :images, :options => 'ENGINE=InnoDB DEFAULT CHARSET=utf8') do |t|
			t.integer :owner_id
			t.string :owner_type

			t.integer :kind
			
			t.string :content_type
			t.string :filename
			t.integer :size
			t.integer :parent_id
			t.string :thumbnail
			t.integer :width
			t.integer :height
	  
			t.timestamps
		end
		add_index :images, [:owner_id, :owner_type], :name=>'owner', :unique=>false
	end

	def self.down
		drop_table :images
	end
end
