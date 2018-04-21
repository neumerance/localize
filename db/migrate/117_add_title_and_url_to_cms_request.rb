class AddTitleAndUrlToCmsRequest < ActiveRecord::Migration
	def self.up
		add_column :cms_requests, :title, :string
		add_column :cms_requests, :permlink, :string
		add_column :cms_target_languages, :title, :string
		add_column :cms_target_languages, :permlink, :string
	end

	def self.down
		remove_column :cms_requests, :title
		remove_column :cms_requests, :permlink
		remove_column :cms_target_languages, :title
		remove_column :cms_target_languages, :permlink
	end
end
