class CreateRevisionLanguages < ActiveRecord::Migration
	def self.up
		create_table(:revision_languages, :options => 'ENGINE=InnoDB DEFAULT CHARSET=utf8') do |t|
			t.column :revision_id, :int
			t.column :language_id, :int
		end
	end

	def self.down
		drop_table :revision_languages
	end
end
