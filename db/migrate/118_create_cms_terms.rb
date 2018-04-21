class CreateCmsTerms < ActiveRecord::Migration
	def self.up
		create_table( :cms_terms, :options => 'ENGINE=InnoDB DEFAULT CHARSET=utf8') do |t|
			t.column :website_id, :int
			t.column :parent_id, :int
			t.column :language_id, :int
			t.column :kind, :string
			t.column :cms_identifier, :int
			t.column :txt, :string

			t.timestamps
		end
		add_index :cms_terms, [:website_id, :kind, :cms_identifier], :name=>'cms_id', :unique => true
		add_index :cms_terms, [:website_id, :parent_id], :name=>'children'
	end

	def self.down
		drop_table :cms_terms
	end
end
