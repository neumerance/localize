class CreateErrorReports < ActiveRecord::Migration
	def self.up
		create_table(:error_reports, :options => 'ENGINE=InnoDB DEFAULT CHARSET=utf8') do |t|
			# submitter
			t.column :email, :string
			
			# support person handling
			t.column :supporter_id, :int
			
			# error description
			t.column :body, :text
			t.column :description, :string
			
			t.column :submit_time, :datetime
			t.column :status, :int
			
			# program details
			t.column :prog, :string
			t.column :version, :string
			t.column :os, :string
		end
	end

	def self.down
		drop_table :error_reports
	end
end
