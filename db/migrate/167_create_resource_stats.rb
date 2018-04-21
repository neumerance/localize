class CreateResourceStats < ActiveRecord::Migration
	def self.up
		create_table( :resource_stats, :options => 'ENGINE=InnoDB DEFAULT CHARSET=utf8') do |t|
			t.column :text_resource_id, :int
			t.column :version_num, :int, :default=>0
			t.column :name, :string
			t.column :count, :int
			t.timestamps
		end
	end

	def self.down
		drop_table :resource_stats
	end
end
