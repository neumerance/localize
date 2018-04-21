class CreateVisits < ActiveRecord::Migration
	def self.up
		create_table(:visits, :options => 'ENGINE=InnoDB DEFAULT CHARSET=utf8') do |t|
			t.column :destination_id, :int
			t.column :source, :string

			t.timestamps
		end
	end

	def self.down
		drop_table :visits
	end
end
