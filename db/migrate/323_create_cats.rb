class CreateCats < ActiveRecord::Migration
	def self.up
		create_table( :cats, :options => 'ENGINE=InnoDB DEFAULT CHARSET=utf8') do |t|
			t.column :name, :string
		end
end

def self.down
	drop_table :cats
	end
end
