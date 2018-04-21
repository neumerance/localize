class AddStatusToFeedback < ActiveRecord::Migration
	def self.up
		add_column :feedbacks, :status, :integer, :default=>FEEDBACK_CREATED
	end

	def self.down
		remove_column :feedbacks, :status
	end
end
