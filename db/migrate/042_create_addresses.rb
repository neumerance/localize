class CreateAddresses < ActiveRecord::Migration
	def self.up
		create_table( :addresses, :options => 'ENGINE=InnoDB DEFAULT CHARSET=utf8') do |t|
			t.column :owner_id, :int
			t.column :owner_type, :string
			
			t.column :country_id, :int
			t.column :address1, :string
			t.column :address1, :string
			t.column :state, :string
			t.column :city, :string
			t.column :zip, :string
		end
	end

	def self.down
		drop_table :addresses
	end
end
