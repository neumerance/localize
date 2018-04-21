class AddDetailsToGlossaryTranslation < ActiveRecord::Migration
	def self.up
		add_column :glossary_translations, :creator_id, :integer
		add_column :glossary_translations, :last_editor_id, :integer
		add_column :glossary_translations, :note, :string
	end

	def self.down
		remove_column :glossary_translations, :creator_id
		remove_column :glossary_translations, :last_editor_id
		remove_column :glossary_translations, :note
	end
end
