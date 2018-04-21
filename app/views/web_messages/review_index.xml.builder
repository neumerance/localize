for message in @messages
	xml.message(:id=>message.id, :payment=>message.translator_payment, :word_count=>message.word_count, :source_language=>message.original_language_id, :destination_language_id=>message.destination_language_id)
end
