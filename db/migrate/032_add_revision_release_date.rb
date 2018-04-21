class AddRevisionReleaseDate < ActiveRecord::Migration
	def self.up
		add_column :revisions, :release_date, :datetime
	end

	def self.down
		remove_column :revisions, :release_date
	end
end
