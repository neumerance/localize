xml.chat(:id=>@chat.id, :is_translator=>(@user==@chat.translator), :is_reviewer=>(@is_reviewer ? true : false)) do
	xml.messages_number(@chat.messages.length)
	xml.translator_id(@chat.translator_id)
	xml.translator_can_access(@chat.translator_can_access)
	if @chat_languages
		xml.work_languages do
			for language in @chat_languages
				xml.language(:lang_id=>language[0].id, :eng_name => language[0].name, :status_code=>language[1], :bid_id=>language[2]) 
			end
		end
	end
	if @bids_disp
		xml.bids do
			for bid_info in @bids_disp
				xml.bid(:lang_id=>bid_info[BID_INFO_LANG_ID],
							:accept_time=>bid_info[BID_INFO_ACCEPT_TIME].to_i,
							:expiration_time=>bid_info[BID_INFO_EXPIRATION_TIME].to_i,
							:completed_percentage=>bid_info[BID_INFO_COMPLETION_PERCENTAGE],
							:amount=>bid_info[BID_INFO_AMOUNT_VAL])
			end
		end
	end
end
