class RemoveReviewFromWebMessages < ActiveRecord::Migration
	def self.up
		remove_column :web_messages, :review_status
	end
	
	def self.down
		add_column :web_messages, :review_status, :integer, :default=>REVIEW_NOT_NEEDED
	end
end
