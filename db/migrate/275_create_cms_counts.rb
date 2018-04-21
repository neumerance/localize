class CreateCmsCounts < ActiveRecord::Migration
	def self.up
		create_table( :cms_counts, :options => 'ENGINE=InnoDB DEFAULT CHARSET=utf8') do |t|
			t.column :cms_count_group_id, :integer
			t.column :website_translation_offer_id, :integer
			t.column :kind, :integer
			t.column :status, :integer
			t.column :count, :integer
			t.column :service, :string
			t.column :priority, :integer, :default=>0
			t.column :code, :string
			t.column :translator_name, :string
		end
		add_index :cms_counts, [:website_translation_offer_id, :kind], :name=>'website_translation_offer_id', :unique=>false
		add_index :cms_counts, [:cms_count_group_id, :kind], :name=>'cms_count_group', :unique=>false
	end

	def self.down
		drop_table :cms_counts
	end
end
