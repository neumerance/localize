class CreateWebDialogs < ActiveRecord::Migration
	def self.up
		create_table( :web_dialogs, :options => 'ENGINE=InnoDB DEFAULT CHARSET=utf8') do |t|
			# owner
			t.column :client_department_id, :int
			
			# languages
			t.column :visitor_language_id, :int
			
			# details of submitter
			t.column :email, :string
			t.column :fname, :string
			t.column :lname, :string
			
			# issue
			t.column :visitor_subject, :string
			t.column :client_subject, :string
			
			# handling
			t.column :status, :int
			t.column :translation_status, :int

			t.column :create_time, :datetime
			t.column :translate_time, :datetime

			# private access key
			t.column :accesskey, :int
		end
	end

	def self.down
		drop_table :web_dialogs
	end
end
