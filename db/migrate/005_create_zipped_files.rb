class CreateZippedFiles < ActiveRecord::Migration
	def self.up
		create_table(:zipped_files, :options => 'ENGINE=InnoDB DEFAULT CHARSET=utf8') do |t|
			t.column :type, :string
			t.column :owner_id, :int
			t.column :chgtime, :datetime
			t.column :description, :string
			
			t.column :content_type, :string
			t.column :filename, :string     
			t.column :size, :int
			t.column :parent_id, :int
		end

	end

	def self.down
		drop_table :zipped_files
	end
end
