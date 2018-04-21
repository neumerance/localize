class PopulateAccesskeyValidation < ActiveRecord::Migration
	def self.up
		Website.all.each { |w| w.update_attributes(:accesskey_ok=>ACCESSKEY_VALIDATED) }
	end

	def self.down
	end
end
