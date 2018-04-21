if @chats
	xml.chats do
		for chat in @chats
			if chat.revision.project.client
				xml.chat(:id=>chat.id, :is_translator=>(chat.translator == @user), :translator_id=>chat.translator.id) do
					xml.translator_can_access(chat.translator_can_access)
					xml.path do
						xml.project(:id => chat.revision.project.id) do
							xml.name(chat.revision.project.name)
						end
						xml.revision(:id => chat.revision.id, :name => chat.revision.name, :released => chat.revision.released, :open_to_bids => chat.revision.open_to_bids, :update_counter=>chat.revision.update_counter, :cms_request_id=>chat.revision.cms_request_id, :translator_can_create_version=>chat.revision.translator_can_create_version(@user)) do
							for version in chat.revision.user_versions(chat.translator)
								if version.user
									xml.version(:id => version.id) do
										xml.filename(version.filename)
										xml.size(version.size)
										xml.created_by(:id => version.user.id,
													:type => version.user[:type],
													:name => version.user.full_name)
										xml.modified(version.chgtime.to_i)
									end
								end
							end
						end
					end
					
					xml.work_languages do
						for language in chat.chat_languages
							xml.language(:eng_name => language[0].name, :status_code=>language[1], :review_status=>language[3]) 
						end
					end
					
					xml.client(chat.revision.project.client.id)
					
				end
			end
		end
	end
end
