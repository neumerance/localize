class CreateClientDepartments < ActiveRecord::Migration
	def self.up
		create_table( :client_departments, :options => 'ENGINE=InnoDB DEFAULT CHARSET=utf8') do |t|
			t.column :web_support_id, :int
			t.column :language_id, :int
			t.column :translation_status_on_create, :int
			t.column :name, :string
		end
	end

	def self.down
		drop_table :client_departments
	end
end
