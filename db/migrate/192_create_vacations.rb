# This migration was originally 192, but was moved to 023b because the migration 024
# requires vacations to exists (as some method on model use that)
class CreateVacations < ActiveRecord::Migration
	def self.up
		drop_table :vacations
		create_table( :vacations, :options => 'ENGINE=InnoDB DEFAULT CHARSET=utf8') do |t|
			t.column :user_id, :int
			t.column :beginning, :datetime
			t.column :end, :datetime
			t.timestamps
		end
	end

	def self.down
		drop_table :vacations
	end
end
