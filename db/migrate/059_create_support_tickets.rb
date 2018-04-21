class CreateSupportTickets < ActiveRecord::Migration
	def self.up
		create_table( :support_tickets, :options => 'ENGINE=InnoDB DEFAULT CHARSET=utf8') do |t|
			t.column :normal_user_id, :int
			t.column :supporter_id, :int
			t.column :support_department_id, :int
			t.column :subject, :string
			t.column :status, :int
			t.column :create_time, :datetime
		end
	end

	def self.down
		drop_table :support_tickets
	end
end
