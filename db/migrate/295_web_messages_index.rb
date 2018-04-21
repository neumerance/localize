class WebMessagesIndex < ActiveRecord::Migration
	def self.up
		add_index :web_messages, [:translation_status, :visitor_language_id, :client_language_id, :user_id, :owner_type], :name=>'search', :unique => false
	end

	def self.down
		remove_index :web_messages, :name=>'search'
	end
end
