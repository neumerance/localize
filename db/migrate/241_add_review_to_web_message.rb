class AddReviewToWebMessage < ActiveRecord::Migration
	def self.up
		add_column :web_messages, :review_status, :integer, :default=>REVIEW_NOT_NEEDED
	end

	def self.down
		remove_column :web_messages, :review_status
	end
end
