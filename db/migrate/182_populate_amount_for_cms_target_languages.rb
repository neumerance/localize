class PopulateAmountForCmsTargetLanguages < ActiveRecord::Migration
	def self.up

		added = 0
		CmsTargetLanguage.where('word_count IS NOT NULL').each do |ctl|
			if !ctl.money_account && ctl.cms_request && ctl.cms_request.website && ctl.cms_request.website.client
				offer = ctl.cms_request.website.website_translation_offers.includes(:website_translation_contracts)
										.where('(website_translation_offers.from_language_id=?)
						AND (website_translation_offers.to_language_id = ?)
						AND(website_translation_contracts.status=?)',ctl.cms_request.language_id,ctl.language_id,TRANSLATION_CONTRACT_ACCEPTED).first
				if offer
						account = ctl.cms_request.website.client.money_accounts.where(currency_id: DEFAULT_CURRENCY_ID).first
						if account
							ctl.amount=offer.amount * ctl.word_count
							ctl.money_account = account
							ctl.save
							added += 1
						end
				end
			end
		end
		puts "Added #{added} expenses"
	
	end

	def self.down
	end
end
