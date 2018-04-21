if @attachments
  xml.attachments do
    for attachment in @attachments
      xml.attachment(:id => attachment.id, :content_type => attachment.content_type) do
        xml.chktime(attachment.chgtime.to_i)
        xml.filename(attachment.filename)
        xml.size(attachment.size)
      end
    end
  end
end
