class ChangeBasePriceForSwLanguagePairs < ActiveRecord::Migration
	def self.up
		AvailableLanguage.where("amount < ?",0.09).each{|al| al.amount = 0.09; al.save}
	end
end
