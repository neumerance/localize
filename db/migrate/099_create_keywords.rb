class CreateKeywords < ActiveRecord::Migration
	def self.up
		create_table( :keywords, :options => 'ENGINE=InnoDB DEFAULT CHARSET=utf8') do |t|
			t.column :parent_id, :int
			t.column :key, :int
			t.column :language_id, :int
			t.column :txt, :string
		end
		add_index :keywords, [:parent_id, :language_id], :name=>'children', :unique => false
		add_index :keywords, [:key, :language_id], :name=>'brothers', :unique => true
	end

	def self.down
		drop_table :keywords
	end
end
