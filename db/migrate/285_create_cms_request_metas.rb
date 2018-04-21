class CreateCmsRequestMetas < ActiveRecord::Migration
	def self.up
		create_table( :cms_request_metas, :options => 'ENGINE=InnoDB DEFAULT CHARSET=utf8') do |t|
			t.column :cms_request_id, :integer
			t.column :name, :string
			t.column :value, :string
			t.timestamps
		end
		
		add_index :cms_request_metas, [:cms_request_id], :name=>'cms_request', :unique=>false
	end

	def self.down
		drop_table :cms_request_metas
	end
end
