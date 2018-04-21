class AddRawRatingToTranslators < ActiveRecord::Migration
	def self.up
		add_column :users, :raw_rating, :integer
	end

	def self.down
		remove_column :users, :raw_rating
	end
end
