class AddPublicStateToTextResources < ActiveRecord::Migration
	def self.up
		add_column :text_resources, :is_public, :integer, :default=>0
	end

	def self.down
		remove_column :text_resources, :is_public
	end
end
