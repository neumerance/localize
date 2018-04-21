class PopulateContractAmount < ActiveRecord::Migration
	def self.up
		WebsiteTranslationOffer.all.each do |offer|
			offer.website_translation_contracts.each do |contract|
				contract.update_attributes!(:amount=>offer.amount, :currency_id=>offer.currency_id)
			end
		end
	end

	def self.down
	end
end
