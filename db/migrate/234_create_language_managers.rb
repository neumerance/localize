class CreateLanguageManagers < ActiveRecord::Migration
	def self.up
		create_table( :language_managers, :options => 'ENGINE=InnoDB DEFAULT CHARSET=utf8') do |t|
			t.integer :client_id
			t.integer :translator_id
			t.integer :from_language_id
			t.integer :to_language_id
			t.integer :status
			t.text :description

			t.timestamps
		end
		add_index :language_managers, [:client_id], :name=>'client', :unique => false
		add_index :language_managers, [:translator_id], :name=>'translator', :unique => false
		add_index :language_managers, [:client_id, :translator_id, :from_language_id, :to_language_id], :name=>'all', :unique => false
	end

	def self.down
		drop_table :language_managers
	end
end
