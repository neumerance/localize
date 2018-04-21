class AddHelpPlacementMask < ActiveRecord::Migration
	def self.up
		remove_column :help_placements, :user_match
		add_column :help_placements, :user_match, :integer, :default=>0
		add_column :help_placements, :user_match_mask, :integer, :default=>0
	end

	def self.down
		remove_column :help_placements, :user_match_mask
	end
end
