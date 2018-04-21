class CreateSerialNumbers < ActiveRecord::Migration
	def self.up
		create_table( :serial_numbers, :options => 'ENGINE=InnoDB DEFAULT CHARSET=utf8') do |t|
		end
	end

	def self.down
		drop_table :serial_numbers
	end
end
