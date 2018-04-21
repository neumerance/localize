class CreateTextResults < ActiveRecord::Migration
	def self.up
		create_table( :text_results, :options => 'ENGINE=InnoDB DEFAULT CHARSET=utf8') do |t|
			t.column :owner_type, :string
			t.column :owner_id, :int
			
			t.column :kind, :string
			t.column :txt, :text

			t.timestamps
		end
	end

	def self.down
		drop_table :text_results
	end
end
