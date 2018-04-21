class RemoveTranslatorFromLanguageManager < ActiveRecord::Migration
	def self.up
		remove_index :language_managers, :name=>'translator'
		remove_column :language_managers, :translator_id
	end

	def self.down
		add_column :language_managers, :translator_id, :integer
		add_index :language_managers, [:translator_id], :name=>'translator', :unique=>false
	end
end
