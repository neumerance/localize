class CreateGlossaryTerms < ActiveRecord::Migration
	def self.up
		create_table( :glossary_terms, :options => 'ENGINE=InnoDB DEFAULT CHARSET=utf8') do |t|
			t.integer :client_id
			t.integer :language_id
			t.string :txt
			t.string :description

			t.timestamps
		end
		add_index :glossary_terms, [:client_id, :txt, :language_id], :name=>'txt', :unique => false
	end

	def self.down
		drop_table :glossary_terms
	end
end
