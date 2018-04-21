class CreateUsersPhones < ActiveRecord::Migration
	def self.up
		create_table( :phones_users, :options => 'ENGINE=InnoDB DEFAULT CHARSET=utf8', :id=>false) do |t|
			t.column :user_id, :integer
			t.column :phone_id, :integer
		end
end

def self.down
	drop_table :phones_users
	end
end
