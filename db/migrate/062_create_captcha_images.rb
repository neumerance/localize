class CreateCaptchaImages < ActiveRecord::Migration
	def self.up
		create_table( :captcha_images, :options => 'ENGINE=InnoDB DEFAULT CHARSET=utf8') do |t|
			# acts as attachment fields
			t.column :content_type, :string
			t.column :filename, :string     
			t.column :size, :integer
			t.column :parent_id,  :integer 
			t.column :width, :integer  
			t.column :height, :integer

			# my fields
			t.column :create_time, :datetime
			t.column :code, :string
		end
	end

	def self.down
		drop_table :captcha_images
	end
end
