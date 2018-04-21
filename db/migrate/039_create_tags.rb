class CreateTags < ActiveRecord::Migration
	def self.up
		create_table( :tags, :options => 'ENGINE=InnoDB DEFAULT CHARSET=utf8') do |t|
			t.column :type, :string
			
			# the object concerned
			t.column :object_id, :int
			t.column :object_type, :string
			
			# tag dependent data
			t.column :contents, :string
		end
	end

	def self.down
		drop_table :tags
	end
end
