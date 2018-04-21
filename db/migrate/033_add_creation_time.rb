class AddCreationTime < ActiveRecord::Migration
	def self.up
		add_column :projects, :creation_time, :datetime
		add_column :revisions, :creation_time, :datetime
	end

	def self.down
		remove_column :projects, :creation_time
		remove_column :revisions, :creation_time
	end
end
