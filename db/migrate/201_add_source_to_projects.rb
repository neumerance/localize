class AddSourceToProjects < ActiveRecord::Migration
	def self.up
		add_column :projects, :source, :integer
	end

	def self.down
		remove_column :projects, :source
	end
end
