class CreateLanguages < ActiveRecord::Migration
	def self.up
		create_table(:languages, :options => 'ENGINE=InnoDB DEFAULT CHARSET=utf8') do |t|
			t.column :name, :string
			t.column :major, :integer, :null => false, :default => 0
		end
	end

	def self.down
		drop_table :languages
	end
end
