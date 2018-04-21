if @chats
	xml.chats do
		for chat in @chats
			xml.chat(:id => chat.id) do
				xml.translator_can_access(chat.translator_can_access)
				xml.messages_length(chat.messages.length)
				xml.path do
					xml.project(:id => chat.revision.project.id) do
						xml.name(chat.revision.project.name)
					end
					xml.revision(:id => chat.revision.id) do
						xml.name(chat.revision.name)
					end
				end
			end
		end
	end
end
