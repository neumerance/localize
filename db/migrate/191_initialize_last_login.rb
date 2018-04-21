class InitializeLastLogin < ActiveRecord::Migration
	def self.up
		t = Time.now-1.week
		User.all.each { |u| u.update_attributes(:last_login=>t) }
	end

	def self.down
	end
end
