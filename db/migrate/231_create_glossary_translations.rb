class CreateGlossaryTranslations < ActiveRecord::Migration
	def self.up
		create_table( :glossary_translations, :options => 'ENGINE=InnoDB DEFAULT CHARSET=utf8') do |t|
			t.integer :glossary_term_id
			t.integer :language_id
			t.string :txt

			t.timestamps
		end
		add_index :glossary_translations, [:glossary_term_id], :name=>'parent', :unique => false
		add_index :glossary_translations, [:txt, :language_id], :name=>'txt', :unique => false
	end

	def self.down
		drop_table :glossary_translations
	end
end
