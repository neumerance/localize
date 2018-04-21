class PopulateWordCount < ActiveRecord::Migration
	def self.up
		CmsRequest.all.each do |cms_request|
			if cms_request.revision
				cms_request.cms_target_languages.each do |cms_target_language|
					wc = cms_request.revision.lang_word_count(cms_target_language.language)
					cms_target_language.update_attributes(:word_count=>wc)
				end
			end
		end
	end

	def self.down
	end
end
