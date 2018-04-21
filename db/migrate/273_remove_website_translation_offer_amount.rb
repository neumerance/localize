class RemoveWebsiteTranslationOfferAmount < ActiveRecord::Migration
	def self.up
		remove_column :website_translation_offers, :amount
		remove_column :website_translation_offers, :currency_id
	end

	def self.down
		add_column :website_translation_offers, :amount, :decimal, {:precision=>8, :scale=>2, :default=>0}
		add_column :website_translation_offers, :currency_id, :integer
	end
end
