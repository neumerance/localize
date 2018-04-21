class CreateLocks < ActiveRecord::Migration
	def self.up
		create_table( :locks, :options => 'ENGINE=InnoDB DEFAULT CHARSET=utf8' ) do |t|
			# locked object	
			t.column :object_type, :string
			t.column :object_id, :string

			# who did the lock
			t.column :locked_by, :string
			
			# time of lock
			t.column :lock_time, :datetime
		end
		add_index :locks, [:object_type, :object_id], :name=>'object', :unique => true
	end

	def self.down
		drop_table :locks
	end
end
