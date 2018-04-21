class AddAdmin < ActiveRecord::Migration
	def self.up
		sysadmin = Admin.create!(:fname => 'amir',
			:lname => 'helzer',
			:nickname => 'sysadmin',
			:email => 'amir.helzer@onthegosystems.com',
			:password => Digest::MD5.hexdigest(Time.now.to_s),
			:userstatus => USER_STATUS_REGISTERED)
	end

	def self.down
	end
end
