class PopulateSearchEngines < ActiveRecord::Migration
	def self.up
		google = SearchEngine.create!(:name=>'Google')
		yahoo = SearchEngine.create!(:name=>'Yahoo!')
		live = SearchEngine.create!(:name=>'Live (Microsoft)')
		
		SearchUrl.create!(:search_engine_id=>google.id, :language_id=>Language.where(['name=?','Arabic']).first.id,
			:url=>"http://www.google.com/search?hl=en&lr=lang_ar&as_q=")
		SearchUrl.create!(:search_engine_id=>google.id, :language_id=>Language.where(['name=?','Chinese']).first.id,
			:url=>"http://www.google.com/search?hl=en&lr=lang_zh-CN&as_q=")
		SearchUrl.create!(:search_engine_id=>google.id, :language_id=>Language.where(['name=?','Japanese']).first.id,
			:url=>"http://www.google.com/search?hl=en&lr=lang_ja&as_q=")
		SearchUrl.create!(:search_engine_id=>google.id, :language_id=>Language.where(['name=?','French']).first.id,
			:url=>"http://www.google.com/search?hl=en&lr=lang_fr&as_q=")
		SearchUrl.create!(:search_engine_id=>google.id, :language_id=>Language.where(['name=?','Spanish']).first.id,
			:url=>"http://www.google.com/search?hl=en&lr=lang_es&as_q=")
		SearchUrl.create!(:search_engine_id=>google.id, :language_id=>Language.where(['name=?','German']).first.id,
			:url=>"http://www.google.com/search?hl=en&lr=lang_de&as_q=")
		SearchUrl.create!(:search_engine_id=>google.id, :language_id=>Language.where(['name=?','English']).first.id,
			:url=>"http://www.google.com/search?hl=en&lr=lang_en&as_q=")
		SearchUrl.create!(:search_engine_id=>google.id, :language_id=>Language.where(['name=?','Dutch']).first.id,
			:url=>"http://www.google.com/search?hl=en&lr=lang_nl&as_q=")
		SearchUrl.create!(:search_engine_id=>google.id, :language_id=>Language.where(['name=?','Italian']).first.id,
			:url=>"http://www.google.com/search?hl=en&lr=lang_it&as_q=")
		SearchUrl.create!(:search_engine_id=>google.id, :language_id=>Language.where(['name=?','Russian']).first.id,
			:url=>"http://www.google.com/search?hl=en&lr=lang_ru&as_q=")
		SearchUrl.create!(:search_engine_id=>google.id, :language_id=>Language.where(['name=?','Korean']).first.id,
			:url=>"http://www.google.com/search?hl=en&lr=lang_ko&as_q=")
		SearchUrl.create!(:search_engine_id=>google.id, :language_id=>Language.where(['name=?','Portuguese']).first.id,
			:url=>"http://www.google.com/search?hl=en&lr=lang_pt&as_q=")
		SearchUrl.create!(:search_engine_id=>google.id, :language_id=>Language.where(['name=?','Romanian']).first.id,
			:url=>"http://www.google.com/search?hl=en&lr=lang_ro&as_q=")
		SearchUrl.create!(:search_engine_id=>google.id, :language_id=>Language.where(['name=?','Danish']).first.id,
			:url=>"http://www.google.com/search?hl=en&lr=lang_da&as_q=")
		SearchUrl.create!(:search_engine_id=>google.id, :language_id=>Language.where(['name=?','Norwegian']).first.id,
			:url=>"http://www.google.com/search?hl=en&lr=lang_no&as_q=")
		SearchUrl.create!(:search_engine_id=>google.id, :language_id=>Language.where(['name=?','Hebrew']).first.id,
			:url=>"http://www.google.com/search?hl=en&lr=lang_he&as_q=")
		SearchUrl.create!(:search_engine_id=>google.id, :language_id=>Language.where(['name=?','Bulgarian']).first.id,
			:url=>"http://www.google.com/search?hl=en&lr=lang_bg&as_q=")
			
		SearchUrl.create!(:search_engine_id=>yahoo.id, :language_id=>Language.where(['name=?','Arabic']).first.id,
			:url=>"http://search.yahoo.com/search?ei=UTF-8&fl=1&vl=lang_ar&p=")
		SearchUrl.create!(:search_engine_id=>yahoo.id, :language_id=>Language.where(['name=?','Chinese']).first.id,
			:url=>"http://search.yahoo.com/search?ei=UTF-8&fl=1&vl=lang_zh-CN&p=")
		SearchUrl.create!(:search_engine_id=>yahoo.id, :language_id=>Language.where(['name=?','Japanese']).first.id,
			:url=>"http://search.yahoo.com/search?ei=UTF-8&fl=1&vl=lang_ja&p=")
		SearchUrl.create!(:search_engine_id=>yahoo.id, :language_id=>Language.where(['name=?','French']).first.id,
			:url=>"http://search.yahoo.com/search?ei=UTF-8&fl=1&vl=lang_fr&p=")
		SearchUrl.create!(:search_engine_id=>yahoo.id, :language_id=>Language.where(['name=?','Spanish']).first.id,
			:url=>"http://search.yahoo.com/search?ei=UTF-8&fl=1&vl=lang_es&p=")
		SearchUrl.create!(:search_engine_id=>yahoo.id, :language_id=>Language.where(['name=?','German']).first.id,
			:url=>"http://search.yahoo.com/search?ei=UTF-8&fl=1&vl=lang_de&p=")
		SearchUrl.create!(:search_engine_id=>yahoo.id, :language_id=>Language.where(['name=?','English']).first.id,
			:url=>"http://search.yahoo.com/search?ei=UTF-8&fl=1&vl=lang_en&p=")
		SearchUrl.create!(:search_engine_id=>yahoo.id, :language_id=>Language.where(['name=?','Dutch']).first.id,
			:url=>"http://search.yahoo.com/search?ei=UTF-8&fl=1&vl=lang_nl&p=")
		SearchUrl.create!(:search_engine_id=>yahoo.id, :language_id=>Language.where(['name=?','Italian']).first.id,
			:url=>"http://search.yahoo.com/search?ei=UTF-8&fl=1&vl=lang_it&p=")
		SearchUrl.create!(:search_engine_id=>yahoo.id, :language_id=>Language.where(['name=?','Russian']).first.id,
			:url=>"http://search.yahoo.com/search?ei=UTF-8&fl=1&vl=lang_ru&p=")
		SearchUrl.create!(:search_engine_id=>yahoo.id, :language_id=>Language.where(['name=?','Korean']).first.id,
			:url=>"http://search.yahoo.com/search?ei=UTF-8&fl=1&vl=lang_ko&p=")
		SearchUrl.create!(:search_engine_id=>yahoo.id, :language_id=>Language.where(['name=?','Portuguese']).first.id,
			:url=>"http://search.yahoo.com/search?ei=UTF-8&fl=1&vl=lang_pt&p=")
		SearchUrl.create!(:search_engine_id=>yahoo.id, :language_id=>Language.where(['name=?','Romanian']).first.id,
			:url=>"http://search.yahoo.com/search?ei=UTF-8&fl=1&vl=lang_ro&p=")
		SearchUrl.create!(:search_engine_id=>yahoo.id, :language_id=>Language.where(['name=?','Danish']).first.id,
			:url=>"http://search.yahoo.com/search?ei=UTF-8&fl=1&vl=lang_da&p=")
		SearchUrl.create!(:search_engine_id=>yahoo.id, :language_id=>Language.where(['name=?','Norwegian']).first.id,
			:url=>"http://search.yahoo.com/search?ei=UTF-8&fl=1&vl=lang_no&p=")
		SearchUrl.create!(:search_engine_id=>yahoo.id, :language_id=>Language.where(['name=?','Hebrew']).first.id,
			:url=>"http://search.yahoo.com/search?ei=UTF-8&fl=1&vl=lang_iw&p=")
		SearchUrl.create!(:search_engine_id=>yahoo.id, :language_id=>Language.where(['name=?','Bulgarian']).first.id,
			:url=>"http://search.yahoo.com/search?ei=UTF-8&fl=1&vl=lang_bg&p=")
			
		SearchUrl.create!(:search_engine_id=>live.id, :language_id=>Language.where(['name=?','Arabic']).first.id,
			:url=>"http://search.live.com/results.aspx?form=QBRE&checkcustom=1&qb=1&q=language%3Aar+")
		SearchUrl.create!(:search_engine_id=>live.id, :language_id=>Language.where(['name=?','Chinese']).first.id,
			:url=>"http://search.live.com/results.aspx?form=QBRE&checkcustom=1&qb=1&q=language%3Azh_chs+")
		SearchUrl.create!(:search_engine_id=>live.id, :language_id=>Language.where(['name=?','Japanese']).first.id,
			:url=>"http://search.live.com/results.aspx?form=QBRE&checkcustom=1&qb=1&q=language%3Aja+")
		SearchUrl.create!(:search_engine_id=>live.id, :language_id=>Language.where(['name=?','French']).first.id,
			:url=>"http://search.live.com/results.aspx?form=QBRE&checkcustom=1&qb=1&q=language%3Afr+")
		SearchUrl.create!(:search_engine_id=>live.id, :language_id=>Language.where(['name=?','Spanish']).first.id,
			:url=>"http://search.live.com/results.aspx?form=QBRE&checkcustom=1&qb=1&q=language%3Aes+")
		SearchUrl.create!(:search_engine_id=>live.id, :language_id=>Language.where(['name=?','German']).first.id,
			:url=>"http://search.live.com/results.aspx?form=QBRE&checkcustom=1&qb=1&q=language%3Ade+")
		SearchUrl.create!(:search_engine_id=>live.id, :language_id=>Language.where(['name=?','English']).first.id,
			:url=>"http://search.live.com/results.aspx?form=QBRE&checkcustom=1&qb=1&q=language%3Aen+")
		SearchUrl.create!(:search_engine_id=>live.id, :language_id=>Language.where(['name=?','Dutch']).first.id,
			:url=>"http://search.live.com/results.aspx?form=QBRE&checkcustom=1&qb=1&q=language%3Anl+")
		SearchUrl.create!(:search_engine_id=>live.id, :language_id=>Language.where(['name=?','Italian']).first.id,
			:url=>"http://search.live.com/results.aspx?form=QBRE&checkcustom=1&qb=1&q=language%3Ait+")
		SearchUrl.create!(:search_engine_id=>live.id, :language_id=>Language.where(['name=?','Russian']).first.id,
			:url=>"http://search.live.com/results.aspx?form=QBRE&checkcustom=1&qb=1&q=language%3Aru+")
		SearchUrl.create!(:search_engine_id=>live.id, :language_id=>Language.where(['name=?','Korean']).first.id,
			:url=>"http://search.live.com/results.aspx?form=QBRE&checkcustom=1&qb=1&q=language%3Ako+")
		SearchUrl.create!(:search_engine_id=>live.id, :language_id=>Language.where(['name=?','Portuguese']).first.id,
			:url=>"http://search.live.com/results.aspx?form=QBRE&checkcustom=1&qb=1&q=language%3Apt+")
		SearchUrl.create!(:search_engine_id=>live.id, :language_id=>Language.where(['name=?','Romanian']).first.id,
			:url=>"http://search.live.com/results.aspx?form=QBRE&checkcustom=1&qb=1&q=language%3Aro+")
		SearchUrl.create!(:search_engine_id=>live.id, :language_id=>Language.where(['name=?','Danish']).first.id,
			:url=>"http://search.live.com/results.aspx?form=QBRE&checkcustom=1&qb=1&q=language%3Ada+")
		SearchUrl.create!(:search_engine_id=>live.id, :language_id=>Language.where(['name=?','Norwegian']).first.id,
			:url=>"http://search.live.com/results.aspx?form=QBRE&checkcustom=1&qb=1&q=language%3Ano+")
		SearchUrl.create!(:search_engine_id=>live.id, :language_id=>Language.where(['name=?','Hebrew']).first.id,
			:url=>"http://search.live.com/results.aspx?form=QBRE&checkcustom=1&qb=1&q=language%3Ahe+")
		SearchUrl.create!(:search_engine_id=>live.id, :language_id=>Language.where(['name=?','Bulgarian']).first.id,
			:url=>"http://search.live.com/results.aspx?form=QBRE&checkcustom=1&qb=1&q=language%3Abg+")
	end

	def self.down
		SearchEngine.delete_all
		SearchUrl.delete_all
	end
end
