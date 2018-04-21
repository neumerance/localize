class AddCmsRequestSearchIndexes < ActiveRecord::Migration
	def self.up
		add_index :cms_requests, [:status], :name=>'status', :unique => false
		add_index :cms_requests, [:status, :language_id, :website_id], :name=>'search', :unique => false
		add_index :cms_target_languages, [:status], :name=>'status', :unique => false
	end

	def self.down
		remove_index :cms_requests, :name=>'status'
		remove_index :cms_requests, :name=>'search'
		remove_index :cms_target_languages, :name=>'status'
	end
end
