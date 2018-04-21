class CreateGoogleLanguages < ActiveRecord::Migration
	def self.up
		create_table( :google_languages, :options => 'ENGINE=InnoDB DEFAULT CHARSET=utf8') do |t|
			t.column :language_id, :int
			t.column :code, :string
		end
	end

	def self.down
		drop_table :google_languages
	end
end
