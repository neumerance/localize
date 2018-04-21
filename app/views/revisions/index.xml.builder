if @revisions
  xml.revisions do
    for revision in @revisions
      xml.revision(:id => revision.id) do
        xml.name(revision.name)
        xml.released(revision.released)
        xml.open_to_bids(revision.open_to_bids)
        xml.versions_number(revision.versions.length)
        xml.chats_number(revision.chats.length)
      end
    end
  end
end
