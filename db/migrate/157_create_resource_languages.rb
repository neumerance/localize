class CreateResourceLanguages < ActiveRecord::Migration
	def self.up
		create_table( :resource_languages, :options => 'ENGINE=InnoDB DEFAULT CHARSET=utf8') do |t|
			t.column :text_resource_id, :int
			t.column :language_id, :int
			t.timestamps
		end
	end

	def self.down
		drop_table :resource_languages
	end
end
