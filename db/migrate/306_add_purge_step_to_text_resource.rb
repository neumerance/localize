class AddPurgeStepToTextResource < ActiveRecord::Migration
	def self.up
		add_column :text_resources, :purge_step, :integer
	end

	def self.down
		remove_column :text_resources, :purge_step
	end
end
