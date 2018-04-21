class AddLoadToTranslators < ActiveRecord::Migration
	def self.up
		add_column :users, :jobs_in_progress, :integer
	end

	def self.down
		remove_column :users, :jobs_in_progress
	end
end
