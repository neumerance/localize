class AddCategoryToWebsites < ActiveRecord::Migration
	def self.up
		add_column :websites, :category_id, :integer
	end

	def self.down
		remove_column :websites, :category_id
	end
end
