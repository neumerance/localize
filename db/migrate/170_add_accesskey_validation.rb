class AddAccesskeyValidation < ActiveRecord::Migration
	def self.up
		add_column :websites, :accesskey_ok, :int, :default=>ACCESSKEY_NOT_VALIDATED
	end

	def self.down
		remove_column :websites, :accesskey_ok
	end
end
