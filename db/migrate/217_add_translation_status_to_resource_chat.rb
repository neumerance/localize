class AddTranslationStatusToResourceChat < ActiveRecord::Migration
	def self.up
		add_column :resource_chats, :translation_status, :integer
	end

	def self.down
		remove_column :resource_chats, :translation_status
	end
end
