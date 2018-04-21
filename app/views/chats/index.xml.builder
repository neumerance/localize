if @chats
  xml.chats do
    for chat in @chats
      xml.chat(:id => chat.id)
    end
  end
end
