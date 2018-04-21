class AddRevisionStats < ActiveRecord::Migration
	def self.up
		add_column :revisions, :stats, :text
	end

	def self.down
		remove_column :revisions, :stats
	end
end
