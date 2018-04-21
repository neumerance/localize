class AddBidDates < ActiveRecord::Migration
	def self.up
		add_column :bids, :expiration_time, :datetime
		add_column :revisions, :bidding_close_time, :datetime
	end

	def self.down
		remove_column :bids, :expiration_time
		remove_column :revisions, :bidding_close_time
	end
end
