class AddCmsTypeToWebsites < ActiveRecord::Migration
	def self.up
		add_column :websites, :cms_kind, :int, :default=>CMS_KIND_DRUPAL
		add_column :websites, :cms_description, :string
	end

	def self.down
		remove_column :websites, :cms_kind
		remove_column :websites, :cms_description
	end
end
