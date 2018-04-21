class AddDeliveredToCmsRequest < ActiveRecord::Migration
	def self.up
		add_column :cms_target_languages, :delivered, :integer
		add_column :cms_requests, :delivered, :integer
	end

	def self.down
		remove_column :cms_target_languages, :delivered
		remove_column :cms_requests, :delivered
	end
end
