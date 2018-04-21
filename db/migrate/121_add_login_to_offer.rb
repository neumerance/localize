class AddLoginToOffer < ActiveRecord::Migration
	def self.up
		add_column :website_translation_offers, :url, :string
		add_column :website_translation_offers, :login, :string
		add_column :website_translation_offers, :password, :string
		add_column :website_translation_offers, :blogid, :integer
	end

	def self.down
		remove_column :website_translation_offers, :url
		remove_column :website_translation_offers, :login
		remove_column :website_translation_offers, :password
		remove_column :website_translation_offers, :blogid
	end
end
