class AddFreeSupportToWebsites < ActiveRecord::Migration
	def self.up
		add_column :websites, :free_support, :integer, :default=>0
	end

	def self.down
		remove_column :websites, :free_support
	end
end
