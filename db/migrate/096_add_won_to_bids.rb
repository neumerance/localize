class AddWonToBids < ActiveRecord::Migration
	def self.up
		add_column :bids, :won, :integer
		add_index :bids, [:revision_language_id, :won], :name=>'bid_won', :unique => true
	end

	def self.down
		remove_column :bids, :won
		remove_index :bids, :name=>'bid_won'
	end
end
