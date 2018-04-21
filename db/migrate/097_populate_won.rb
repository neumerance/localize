class PopulateWon < ActiveRecord::Migration
	def self.up
		Bid.all.each { |bid| bid.save! }
	end

	def self.down
	end
end
