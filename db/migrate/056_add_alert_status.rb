class AddAlertStatus < ActiveRecord::Migration
	def self.up
		add_column :revisions, :alert_status, :integer, :default => 0
		add_column :bids, :alert_status, :integer, :default => 0
	end

	def self.down
		remove_column :revisions, :alert_status
		remove_column :bids, :alert_status
	end
end
