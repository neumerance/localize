class AddIndexToStringTranslation < ActiveRecord::Migration
	def self.up
		add_index :string_translations, [:resource_string_id, :status, :language_id], :name=>'parent', :unique => false
		add_index :string_translations, [:resource_string_id, :language_id], :name=>'parent_and_language', :unique => true
		add_index :string_translations, [:resource_string_id, :status, :language_id], :name=>'parent_language_and_status', :unique => false
	end

	def self.down
		remove_index :string_translations, :name=>'parent'
		remove_index :string_translations, :name=>'parent_and_language'
		remove_index :string_translations, :name=>'parent_language_and_status'
	end
end
