class CreateSearchEngines < ActiveRecord::Migration
	def self.up
		create_table( :search_engines, :options => 'ENGINE=InnoDB DEFAULT CHARSET=utf8') do |t|
			t.column :name, :string
		end
	end

	def self.down
		drop_table :search_engines
	end
end
