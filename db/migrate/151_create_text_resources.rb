class CreateTextResources < ActiveRecord::Migration
	def self.up
		create_table( :text_resources, :options => 'ENGINE=InnoDB DEFAULT CHARSET=utf8') do |t|
			t.column :client_id, :int
			t.column :language_id, :int
			t.column :resource_format_id, :int
			t.column :name, :string
			t.column :description, :string
			t.timestamps
		end
	end

	def self.down
		drop_table :text_resources
	end
end
