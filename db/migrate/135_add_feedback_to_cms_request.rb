class AddFeedbackToCmsRequest < ActiveRecord::Migration
	def self.up
		add_column :cms_requests, :last_operation, :integer
		add_column :cms_requests, :pending_tas, :integer, :default=>0
	end

	def self.down
		remove_column :cms_requests, :last_operation
		remove_column :cms_requests, :pending_tas
	end
end
