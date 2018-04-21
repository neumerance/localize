class CreateInvitations < ActiveRecord::Migration
	def self.up
		create_table( :invitations, :options => 'ENGINE=InnoDB DEFAULT CHARSET=utf8') do |t|
			t.column :normal_user_id, :int
			t.column :name, :string
			t.column :message, :text
			t.column :active, :int, :default=>0
			t.timestamps
		end
	end

	def self.down
		drop_table :invitations
	end
end
