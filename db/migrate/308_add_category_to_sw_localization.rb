class AddCategoryToSwLocalization < ActiveRecord::Migration
	def self.up
		add_column :text_resources, :category_id, :integer
	end

	def self.down
		remove_column :text_resources, :category_id
	end
end
