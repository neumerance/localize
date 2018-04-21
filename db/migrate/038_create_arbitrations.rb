class CreateArbitrations < ActiveRecord::Migration
	def self.up
		create_table(:arbitrations, :options => 'ENGINE=InnoDB DEFAULT CHARSET=utf8') do |t|
			# type of arbitration
			t.column :type_code, :int

			# the object concerned
			t.column :object_id, :int
			t.column :object_type, :string

			# parties involved
			t.column :initiator_id, :int
			t.column :against_id, :int
			t.column :supporter_id, :int
			
			# status
			t.column :status, :int
			t.column :resolution, :int
			t.column :payment_amount, :decimal, {:precision=>8, :scale=>2, :default=>0}
		end
		add_index :arbitrations, [:object_id, :object_type], :name=>'object', :unique => true
	end

	def self.down
		drop_table :arbitrations
	end
end
