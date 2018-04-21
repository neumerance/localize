class PopulateAccesskey < ActiveRecord::Migration
	def self.up
		Website.all.each do |website|
			website.update_attributes(:accesskey=>website.old_accesskey())
		end
	end

	def self.down
	end
end
