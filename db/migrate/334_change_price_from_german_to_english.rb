class ChangePriceFromGermanToEnglish < ActiveRecord::Migration
	def self.up
		AvailableLanguage.where(from_language_id: Language.find_by_name("German").id,to_language_id: Language.find_by_name("English").id).each{|al| al.amount = 0.10; al.save}
	end
end
