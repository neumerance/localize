class CreateUsersCats< ActiveRecord::Migration
	def self.up
		create_table( :cats_users, :options => 'ENGINE=InnoDB DEFAULT CHARSET=utf8', :id=>false) do |t|
			t.column :user_id, :integer
			t.column :cat_id, :integer
		end
end

def self.down
	drop_table :cats_users
	end
end
