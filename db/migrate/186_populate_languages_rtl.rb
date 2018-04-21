class PopulateLanguagesRtl < ActiveRecord::Migration
	def self.up
		rtl_languages = ['Arabic','Persian','Hebrew']
		rtl_languages.each do |lang_name|
			language = Language.where(name: lang_name).first
			language.update_attributes!(:rtl=>1)
		end
	end

	def self.down
	end
end
