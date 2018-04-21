class CloseOffers < ActiveRecord::Migration
	def self.up
		add_column :website_translation_offers, :status, :integer, :default=>TRANSLATION_OFFER_OPEN
	end

	def self.down
		remove_column :website_translation_offers, :status
	end
end
