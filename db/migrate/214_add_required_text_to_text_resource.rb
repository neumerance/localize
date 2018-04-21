class AddRequiredTextToTextResource < ActiveRecord::Migration
	def self.up
		add_column :text_resources, :required_text, :string
	end

	def self.down
		remove_column :text_resources, :required_text
	end
end
