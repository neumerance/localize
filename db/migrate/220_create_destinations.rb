class CreateDestinations < ActiveRecord::Migration
	def self.up
		create_table( :destinations, :options => 'ENGINE=InnoDB DEFAULT CHARSET=utf8') do |t|
			t.string :url
			t.integer :language_id
			t.string :name

			t.timestamps
		end
	end

	def self.down
		drop_table :destinations
	end
end
