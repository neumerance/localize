class CreateWebSupports < ActiveRecord::Migration
	def self.up
		create_table( :web_supports, :options => 'ENGINE=InnoDB DEFAULT CHARSET=utf8') do |t|
			t.column :client_id, :int
			t.column :name, :string
			t.timestamps
		end
	end

	def self.down
		drop_table :web_supports
	end
end
