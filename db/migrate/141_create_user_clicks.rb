class CreateUserClicks < ActiveRecord::Migration
	def self.up
		create_table( :user_clicks, :options => 'ENGINE=InnoDB DEFAULT CHARSET=utf8') do |t|
			t.column :user_id, :int
			t.column :controller, :string
			t.column :action, :string
			t.column :params, :string
			t.timestamps
		end
	end

	def self.down
		drop_table :user_clicks
	end
end
