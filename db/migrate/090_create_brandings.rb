class CreateBrandings < ActiveRecord::Migration
	def self.up
		create_table( :brandings, :options => 'ENGINE=InnoDB DEFAULT CHARSET=utf8') do |t|
			t.column :owner_type, :string
			t.column :owner_id, :int

			t.column :language_id, :int
		
			t.column :logo_url, :string
			t.column :logo_width, :int
			t.column :logo_height, :int
			t.column :home_url, :string
		end
		# make sure only a single branding can exist for on object in a given language
		add_index :brandings, [:owner_type, :owner_id, :language_id], :name=>'language_for_owner', :unique => true
	end

	def self.down
		drop_table :brandings
	end
end
