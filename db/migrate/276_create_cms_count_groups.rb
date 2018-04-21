class CreateCmsCountGroups < ActiveRecord::Migration
	def self.up
		create_table( :cms_count_groups, :options => 'ENGINE=InnoDB DEFAULT CHARSET=utf8') do |t|
			t.column :website_id, :integer
			t.timestamps
		end

		add_index :cms_count_groups, [:website_id], :name=>'website', :unique=>false
		add_index :cms_count_groups, [:website_id, :created_at], :name=>'website_by_time', :unique=>false
	end

	def self.down
		drop_table :cms_count_groups
	end
end
