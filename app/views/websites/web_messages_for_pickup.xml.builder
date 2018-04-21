xml.web_messages_for_pickup do
	@web_messages.each do |web_message|
		xml.web_message(Base64.encode64(web_message.client_body), :id=>web_message.id, :create_time=>web_message.create_time.to_i, :translate_time=>web_message.translate_time.to_i)
	end
end