class AddContextToResourceStrings < ActiveRecord::Migration
	def self.up
		add_column :resource_strings, :context, :string
	end

	def self.down
		remove_column :resource_strings, :context
	end
end
