class AddLastEditorToStringTranslations < ActiveRecord::Migration
	def self.up
		add_column :string_translations, :last_editor_id, :integer
	end

	def self.down
		remove_column :string_translations, :last_editor_id
	end
end
