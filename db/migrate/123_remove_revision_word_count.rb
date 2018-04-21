class RemoveRevisionWordCount < ActiveRecord::Migration
	def self.up
		remove_column :revisions, :word_count
	end

	def self.down
		add_column :revisions, :word_count, :integer, :default=>0
	end
end
