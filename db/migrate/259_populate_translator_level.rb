class PopulateTranslatorLevel < ActiveRecord::Migration
	def self.up
		Translator.where('userstatus IN (?)',[USER_STATUS_REGISTERED,USER_STATUS_QUALIFIED]).each do |translator|
			rating = translator.rating.to_i
			level = (rating > MIN_RATING_FOR_EXPERT_TRANSLATOR) ? EXPERT_TRANSLATOR : NORMAL_TRANSLATOR
			translator.update_attributes(:level=>level)
		end
	end

	def self.down
	end
end
