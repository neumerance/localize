class AddTmControlsToTextResource < ActiveRecord::Migration
	def self.up
		add_column :text_resources, :tm_use_mode, :integer, :default=>TM_COMPLETE_MATCHES
		add_column :text_resources, :tm_use_threshold, :integer, :default=>5
	end

	def self.down
		remove_column :text_resources, :tm_use_mode
		remove_column :text_resources, :tm_use_threshold
	end
end
