class CreateDbContentTranslations < ActiveRecord::Migration
	def self.up
		create_table( :db_content_translations, :options => 'ENGINE=InnoDB DEFAULT CHARSET=utf8') do |t|
			t.column :owner_id, :int
			t.column :owner_type, :string

			t.column :language_id, :int
			t.column :txt, :string

		end
	end

	def self.down
		drop_table :db_content_translations
	end
end
