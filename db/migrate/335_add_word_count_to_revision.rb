class AddWordCountToRevision < ActiveRecord::Migration
	def self.up
		add_column :revisions, :word_count, :integer
	end

	def self.down
		remove_column :revisions, :word_count
	end
end
