class CreateCountries < ActiveRecord::Migration
	def self.up
		create_table( :countries, :options => 'ENGINE=InnoDB DEFAULT CHARSET=utf8') do |t|
			t.column :code, :string
			t.column :name, :string
			t.column :language_id, :int
			t.column :major, :int
		end
	end

	def self.down
		drop_table :countries
	end
end
