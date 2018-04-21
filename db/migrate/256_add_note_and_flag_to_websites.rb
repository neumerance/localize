class AddNoteAndFlagToWebsites < ActiveRecord::Migration
	def self.up
		add_column :websites, :note, :text
		add_column :websites, :flag, :integer, :default=>0
	end

	def self.down
		remove_column :websites, :note
		remove_column :websites, :flag
	end
end
