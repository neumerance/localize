class CreateContacts < ActiveRecord::Migration
	def self.up
		create_table( :contacts, :options => 'ENGINE=InnoDB DEFAULT CHARSET=utf8') do |t|
			# details of submitter
			t.column :email, :string
			t.column :fname, :string
			t.column :lname, :string
			
			# issue
			t.column :department, :int
			t.column :subject, :string
			
			# handling
			t.column :supporter_id, :int
			t.column :status, :int
			t.column :create_time, :datetime

			# private access key
			t.column :accesskey, :int
		end
	end

	def self.down
		drop_table :contacts
	end
end
