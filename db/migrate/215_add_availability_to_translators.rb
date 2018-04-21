class AddAvailabilityToTranslators < ActiveRecord::Migration
	def self.up
		add_column :users, :available_for_cms, :integer
	end

	def self.down
		remove_column :users, :available_for_cms
	end
end
