xml.message(:id=>@web_message.id, :source_language=>@web_message.original_language_id, :destination_language_id=>@web_message.destination_language_id,
	:word_count=>@web_message.word_count, :payment=>@web_message.translator_payment, :timeout=>@web_message.timeout, :translation_status=>@web_message.translation_status,
	:message_owned=>@web_message.belongs_to_user?(@user), :client_id=>(@client ? @client.id : 0) ) do
	xml.body(@web_message.text_to_translate, :text_md5=>@web_message.text_md5)
	if @web_message.need_title_translation()
		xml.title(@web_message.title_to_translate, :title_md5=>@web_message.title_md5)
	end
	if !@web_message.comment.blank?
		xml.comment(@web_message.encoded_comment, :comment_md5=>@web_message.comment_md5)
	end
end
