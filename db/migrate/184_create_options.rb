class CreateOptions < ActiveRecord::Migration
	def self.up
		create_table( :options, :options => 'ENGINE=InnoDB DEFAULT CHARSET=utf8') do |t|
			t.column :name, :string
			t.column :value, :string
			t.timestamps
		end
	end

	def self.down
		drop_table :options
	end
end
