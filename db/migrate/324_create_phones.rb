class CreatePhones< ActiveRecord::Migration
	def self.up
		create_table( :phones, :options => 'ENGINE=InnoDB DEFAULT CHARSET=utf8') do |t|
			t.column :name, :string
		end
end

def self.down
	drop_table :phones
	end
end
