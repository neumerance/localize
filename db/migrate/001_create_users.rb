class CreateUsers < ActiveRecord::Migration
	def self.up
		create_table(:users, :options => 'ENGINE=InnoDB DEFAULT CHARSET=utf8') do |t|
		# class type identifier
		t.column :type, :string

		# for client, translator and staff
		t.column :fname, :string
		t.column :lname, :string
		t.column :email, :string
		t.column :password, :string

		t.column :nickname, :string
		t.column :verification_level, :integer, :default=>0

		# for client and translator
		t.column :userstatus, :int
		t.column :locale, :string
	end
	add_index :users, [:email], :name=>'email', :unique => true
	add_index :users, [:nickname], :name=>'nickname', :unique => true
end

def self.down
	drop_table :users
	end
end
