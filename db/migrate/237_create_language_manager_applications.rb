class CreateLanguageManagerApplications < ActiveRecord::Migration
	def self.up
		create_table( :language_manager_applications, :options => 'ENGINE=InnoDB DEFAULT CHARSET=utf8') do |t|
			t.integer :language_manager_id
			t.integer :translator_id
			t.integer :status

			t.timestamps
		end
		add_index :language_manager_applications, [:translator_id], :name=>'translator', :unique => false
	end

	def self.down
		drop_table :language_manager_applications
	end
end
