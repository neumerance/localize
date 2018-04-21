class AddMaxStringWidth < ActiveRecord::Migration
	def self.up
		add_column :resource_strings, :max_width, :integer
	end

	def self.down
		remove_column :resource_strings, :max_width
	end
end
