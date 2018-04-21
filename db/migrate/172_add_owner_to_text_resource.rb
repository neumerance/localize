class AddOwnerToTextResource < ActiveRecord::Migration
	def self.up
		add_column :text_resources, :owner_id, :integer
		add_column :text_resources, :owner_type, :string
	end

	def self.down
		remove_column :text_resources, :owner_id
		remove_column :text_resources, :owner_type
	end
end
