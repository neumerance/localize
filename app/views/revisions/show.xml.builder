xml.revision(:id => @revision.id, :name=> @revision.name, :released => @revision.released, :open_to_bids => @revision.open_to_bids, :update_counter=>@revision.update_counter, :is_test=>@revision.is_test? ) do
	if @revision.language
		xml.source_language(:id=>@revision.language_id, :name=>@revision.language.name)
	end
	for version in @revision.versions
		xml.version(:id => version.id) do
			if @extra_info
				xml.created_by(:id => version.user.id, :type => version.user[:type], :name => version.user.full_name)
				xml.modified(version.chgtime.to_i)
				for language in version.translation_languages
					xml.language(:id=>language.id, :name=>language.name)
				end
			end
		end
	end
	for chat in @revision.chats
		xml.chat(:id => chat.id) do
			if @extra_info
				xml.bids do
					for bid in chat.bids
						xml.bid(:lang_id=>bid.revision_language.language.id,
							:accept_time=>bid.accept_time,
							:expiration_time=>bid.expiration_time,
							:amount=>bid.amount)
					end
				end
			end
		end
	end
	for revision_language in @revision.revision_languages
		xml.language(:id => revision_language.language.id, :name => revision_language.language.name)
	end
	xml.stats do
		if @document_count
			@document_count.each do |lang, c1|
				c1.each do |status, count|
					xml.document_count(:lang => lang, :status => WORDS_STATUS_TEXT[status], :count => count)
				end
			end
		end
		if @sentence_count
			@sentence_count.each do |lang, c1|
				c1.each do |status, count|
					xml.sentence_count(:lang => lang, :status => WORDS_STATUS_TEXT[status], :count => count)
				end
			end
		end
		if @word_count
			@word_count.each do |lang, c1|
				c1.each do |status, count|
					xml.word_count(:lang => lang, :status => WORDS_STATUS_TEXT[status], :count => count)
				end
			end
		end
		if @support_files_count
			@support_files_count.each do |lang, c1|
				c1.each do |status, count|
					xml.support_files_count(:lang => lang, :status => WORDS_STATUS_TEXT[status], :count => count)
				end
			end
		end
	end
	xml.work_complete(@revision.work_complete)
end
