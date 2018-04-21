class CreateManagedWorks < ActiveRecord::Migration
	def self.up
		create_table :managed_works do |t|
			t.integer :translator_id
			t.integer :owner_id
			t.string :owner_type
			t.integer :active, :default=>MANAGED_WORK_ACTIVE
			t.integer :translation_status, :default=>MANAGED_WORK_CREATED

			t.timestamps
		end
		add_index :managed_works, [:translator_id], :name=>'translator', :unique=>false
		add_index :managed_works, [:owner_type, :owner_id], :name=>'owner', :unique=>false
	end

	def self.down
		drop_table :managed_works
	end
end
