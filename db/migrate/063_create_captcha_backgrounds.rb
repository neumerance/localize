class CreateCaptchaBackgrounds < ActiveRecord::Migration
	def self.up
		create_table( :captcha_backgrounds, :options => 'ENGINE=InnoDB DEFAULT CHARSET=utf8') do |t|
			t.column :fname, :string
		end
	end

	def self.down
		drop_table :captcha_backgrounds
	end
end
