class SplitChinese < ActiveRecord::Migration
	def self.up
		google = SearchEngine.where(name: 'Google').first
		yahoo = SearchEngine.where(name: 'Yahoo!').first
		live = SearchEngine.where(name: 'Live (Microsoft)').first

		cn_s = Language.where(name: 'Chinese').first
		cn_s.update_attributes!(:name=>'Chinese (Simplified)')
		cn_t = Language.create(:name=>'Chinese (Traditional)', :major=>1)

		tls = TranslatorLanguage.where('(language_id=?) AND (status=?)',cn_s.id,TRANSLATOR_LANGUAGE_APPROVED)
		tls.each do |tl|
			tl_new = TranslatorLanguage.new(:language_id=>cn_t.id,
										:status=>tl.status,
										:description=>'Automatically duplicated from Simplified Chinese',
										:translator_id=>tl.translator_id)
			tl_new[:type] = tl[:type]
			tl_new.save!
		end

		SearchUrl.create!(:search_engine_id=>google.id, :language_id=>Language.where(name: 'Chinese (Traditional)').first.id,
			:url=>"http://www.google.com/search?hl=en&lr=lang_zh-TW&as_q=")
		SearchUrl.create!(:search_engine_id=>yahoo.id, :language_id=>Language.where(name: 'Chinese (Traditional)').first.id,
			:url=>"http://search.yahoo.com/search?ei=UTF-8&fl=1&vl=lang_zh-TW&p=")
		SearchUrl.create!(:search_engine_id=>live.id, :language_id=>Language.where(name: 'Chinese (Traditional)').first.id,
			:url=>"http://search.live.com/results.aspx?form=QBRE&checkcustom=1&qb=1&q=language%3Azh_cht+")

	end

	def self.down
		cn_s = Language.where(name: 'Chinese (Simplified)').first
		cn_s.update_attributes!(:name=>'Chinese')
		cn_t = Language.where(name: 'Chinese (Traditional)').first
		cn_t.destroy
	end
end
