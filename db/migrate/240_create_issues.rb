class CreateIssues < ActiveRecord::Migration
	def self.up
		create_table( :issues, :options => 'ENGINE=InnoDB DEFAULT CHARSET=utf8') do |t|
			t.integer :owner_id
			t.string :owner_type

			t.integer :initiator_id
			t.integer :target_id
			
			t.integer :kind
			t.integer :status
			
			t.string :title
			
			t.timestamps
		end
		add_index :issues, [:initiator_id], :name=>'initiator', :unique=>false
		add_index :issues, [:target_id], :name=>'target', :unique=>false
		add_index :issues, [:owner_type, :owner_id], :name=>'owner', :unique=>false
	end

	def self.down
		drop_table :issues
	end
end
