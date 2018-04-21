class AddNoteAndFlagToUsers < ActiveRecord::Migration
	def self.up
		add_column :users, :note, :text
		add_column :users, :flag, :boolean
	end

	def self.down
		remove_column :users, :note
		remove_column :users, :flag
	end
end
