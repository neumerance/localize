class AddIndexToRevisionLanguage < ActiveRecord::Migration
	def self.up
		duplicate_rl = RevisionLanguage.find_by_sql('SELECT DISTINCT rl.* FROM revision_languages rl WHERE
					EXISTS (SELECT higher_rl.* FROM revision_languages higher_rl WHERE ((higher_rl.revision_id=rl.revision_id) AND
					(higher_rl.language_id=rl.language_id) AND (higher_rl.id>rl.id)))')
		duplicate_rl.each { |rl| rl.destroy }
		add_index :revision_languages, [:revision_id, :language_id], :name=>'single_rl', :unique => true
	end

	def self.down
		remove_index :revision_languages, :name=>'single_rl'
	end
end
