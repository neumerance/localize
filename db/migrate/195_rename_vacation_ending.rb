class RenameVacationEnding < ActiveRecord::Migration
	def self.up
		rename_column :vacations, :end, :ending
	end

	def self.down
		rename_column :vacations, :ending, :end
	end
end
