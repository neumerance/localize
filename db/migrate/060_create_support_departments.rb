class CreateSupportDepartments < ActiveRecord::Migration
	def self.up
		create_table( :support_departments, :options => 'ENGINE=InnoDB DEFAULT CHARSET=utf8') do |t|
			t.column :name, :string
			t.column :description, :string
		end
	end

	def self.down
		drop_table :support_departments
	end
end
