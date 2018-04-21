class CreateResourceStrings < ActiveRecord::Migration
	def self.up
		create_table( :resource_strings, :options => 'ENGINE=InnoDB DEFAULT CHARSET=utf8') do |t|
			t.column :text_resource_id, :int
			t.column :token, :string
			t.column :txt, :text
			t.timestamps
		end
	end

	def self.down
		drop_table :resource_strings
	end
end
