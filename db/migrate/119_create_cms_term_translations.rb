class CreateCmsTermTranslations < ActiveRecord::Migration
	def self.up
		create_table( :cms_term_translations, :options => 'ENGINE=InnoDB DEFAULT CHARSET=utf8') do |t|
			t.column :cms_term_id, :int
			t.column :language_id, :int
			t.column :txt, :string
			t.column :status, :int
			t.column :cms_identifier, :int

			t.timestamps
		end
		add_index :cms_term_translations, [:cms_term_id], :name=>'parent'
	end

	def self.down
		drop_table :cms_term_translations
	end
end
