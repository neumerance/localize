class AddDownloadDetails < ActiveRecord::Migration
	def self.up
		add_column :downloads, :usertype, :string
		add_column :downloads, :os_code, :integer, :default=>0
	end

	def self.down
		remove_column :downloads, :usertype
		remove_column :downloads, :os_code
	end
end
