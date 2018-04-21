class AddPublicCaptcha < ActiveRecord::Migration
	def self.up
		add_column :captcha_images, :user_rand, :integer
		add_column :captcha_images, :client_id, :integer
		add_index :captcha_images, [:user_rand, :client_id], :name=>'client_user_rand', :unique => true
		
		create_table( :captcha_keys, :options => 'ENGINE=InnoDB DEFAULT CHARSET=utf8') do |t|
			t.column :client_id, :int
			t.column :access_key, :string
		end
		add_index :captcha_keys, [:client_id, :access_key], :name=>'client_key', :unique => true
	end

	def self.down
		drop_table :captcha_keys
		remove_index :captcha_images, :name=>'client_user_rand'
		remove_column :captcha_images, :client_id
		remove_column :captcha_images, :user_rand
	end
end
