class CreateStringTranslations < ActiveRecord::Migration
	def self.up
		create_table( :string_translations, :options => 'ENGINE=InnoDB DEFAULT CHARSET=utf8') do |t|
			t.column :resource_string_id, :int
			t.column :language_id, :int
			t.column :txt, :text
			t.column :status, :int, :default=>STRING_TRANSLATION_NEEDS_UPDATE

			t.timestamps
		end
	end

	def self.down
		drop_table :string_translations
	end
end
