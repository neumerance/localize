class CreateBookmarks < ActiveRecord::Migration
	def self.up
		create_table(:bookmarks, :options => 'ENGINE=InnoDB DEFAULT CHARSET=utf8') do |t|
			t.column :user_id, :int
			t.column :resource_id, :int
			t.column :resource_type, :string
			t.column :note, :string			
		end
	end

	def self.down
		drop_table :bookmarks
	end
end
