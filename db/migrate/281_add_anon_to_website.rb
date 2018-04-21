class AddAnonToWebsite < ActiveRecord::Migration
	def self.up
		add_column :websites, :anon, :integer, :default=>0
	end

	def self.down
		remove_column :websites, :anon
	end
end
