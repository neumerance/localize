class AddAccesskeyToWebsite < ActiveRecord::Migration
	def self.up
		add_column :websites, :accesskey, :string
	end

	def self.down
		remove_column :websites, :accesskey
	end
end
