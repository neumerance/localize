class AddNoteAndFlagToTextResourcesAndRevisions < ActiveRecord::Migration
	def self.up
		add_column :text_resources, :note, :text
		add_column :revisions, :note, :text
		add_column :text_resources, :flag, :boolean, :default => false
		add_column :revisions, :flag, :boolean, :default => false
	end

	def self.down
		remove_column :text_resources, :note
		remove_column :revisions, :note
		remove_column :revisions, :flag
		remove_column :revisions, :flag
	end
end
