class AddIndexes < ActiveRecord::Migration
	def self.up
		add_index :account_lines, [:account_type, :account_id], :name=>'account', :unique => false
		add_index :attachments, [:message_id], :name=>'message', :unique => false
		add_index :money_accounts, [:type, :owner_id], :name=>'owner', :unique => false
		add_index :zipped_files, [:type, :owner_id], :name=>'owner', :unique => false
		add_index :bids, [:chat_id], :name=>'chat', :unique => false
		add_index :bids, [:revision_language_id], :name=>'revision_language', :unique => false
		add_index :chats, [:revision_id], :name=>'revision', :unique => false
		add_index :chats, [:translator_id], :name=>'translator', :unique => false
		add_index :revisions, [:project_id], :name=>'project', :unique => false
		add_index :revisions, [:cms_request_id], :name=>'cms_request', :unique => false
		add_index :cms_requests, [:website_id], :name=>'website', :unique => false
		add_index :cms_requests, [:language_id], :name=>'language', :unique => false
		add_index :cms_target_languages, [:cms_request_id], :name=>'cms_request', :unique => false
		add_index :cms_target_languages, [:language_id], :name=>'language', :unique => false
		add_index :cms_target_languages, [:translator_id], :name=>'translator', :unique => false
		add_index :external_accounts, [:owner_id], :name=>'owner', :unique => false
		add_index :messages, [:owner_type, :owner_id], :name=>'owner', :unique => false
		add_index :money_transactions, [:source_account_type, :source_account_id], :name=>'source_account', :unique => false
		add_index :money_transactions, [:target_account_type, :target_account_id], :name=>'target_account', :unique => false
		add_index :money_transactions, [:owner_type, :owner_id], :name=>'owner', :unique => false
		add_index :reminders, [:owner_type, :owner_id], :name=>'owner', :unique => false
		add_index :reminders, [:normal_user_id], :name=>'normal_user', :unique => false
		add_index :resource_chats, [:translator_id], :name=>'translator', :unique => false
		add_index :resource_chats, [:resource_language_id], :name=>'resource_language', :unique => false
		add_index :resource_languages, [:text_resource_id], :name=>'text_resource', :unique => false
		add_index :resource_strings, [:text_resource_id], :name=>'text_resource', :unique => false
		add_index :sent_notifications, [:owner_type, :owner_id], :name=>'owner', :unique => false
		add_index :statistics, [:version_id], :name=>'version', :unique => false
		add_index :support_tickets, [:normal_user_id], :name=>'normal_user', :unique => false
		add_index :support_tickets, [:supporter_id], :name=>'supporter', :unique => false
		add_index :client_departments, [:web_support_id], :name=>'web_support', :unique => false
		add_index :web_dialogs, [:client_department_id], :name=>'client_department', :unique => false
		add_index :web_messages, [:owner_type, :owner_id], :name=>'owner', :unique => false
		add_index :web_messages, [:user_id], :name=>'user', :unique => false
		add_index :web_messages, [:translator_id], :name=>'translator', :unique => false
		add_index :websites, [:client_id], :name=>'client', :unique => false
		add_index :website_translation_contracts, [:translator_id], :name=>'translator', :unique => false
		add_index :website_translation_contracts, [:website_translation_offer_id], :name=>'website_translation_offer', :unique => false
		add_index :website_translation_offers, [:website_id], :name=>'website', :unique => false
		add_index :web_supports, [:client_id], :name=>'client', :unique => false
		
	end

	def self.down
		remove_index :account_lines, :name=>'account'
		remove_index :attachments, :name=>'message'
		remove_index :money_accounts, :name=>'owner'
		remove_index :zipped_files, :name=>'owner'
		remove_index :bids, :name=>'chat'
		remove_index :bids, :name=>'revision_language'
		remove_index :chats, :name=>'revision'
		remove_index :chats, :name=>'translator'
		remove_index :revisions, :name=>'project'
		remove_index :revisions, :name=>'cms_request'
		remove_index :cms_requests, :name=>'website'
		remove_index :cms_requests, :name=>'language'
		remove_index :cms_target_languages, :name=>'cms_request'
		remove_index :cms_target_languages, :name=>'language'
		remove_index :cms_target_languages, :name=>'translator'
		remove_index :external_accounts, :name=>'owner'
		remove_index :messages, :name=>'owner'
		remove_index :money_transactions, :name=>'source_account'
		remove_index :money_transactions, :name=>'target_account'
		remove_index :money_transactions, :name=>'owner'
		remove_index :reminders, :name=>'owner'
		remove_index :reminders, :name=>'normal_user'
		remove_index :resource_chats, :name=>'translator'
		remove_index :resource_chats, :name=>'resource_language'
		remove_index :resource_languages, :name=>'text_resource'
		remove_index :resource_strings, :name=>'text_resource'
		remove_index :sent_notifications, :name=>'owner'
		remove_index :statistics, :name=>'version'
		remove_index :support_tickets, :name=>'normal_user'
		remove_index :support_tickets, :name=>'supporter'
		remove_index :client_departments, :name=>'web_support'
		remove_index :web_dialogs, :name=>'client_department'
		remove_index :web_messages, :name=>'owner'
		remove_index :web_messages, :name=>'user'
		remove_index :web_messages, :name=>'translator'
		remove_index :websites, :name=>'client'
		remove_index :website_translation_contracts, :name=>'translator'
		remove_index :website_translation_contracts, :name=>'website_translation_offer'
		remove_index :website_translation_offers, :name=>'website'
		remove_index :web_supports, :name=>'client'
	end
end
