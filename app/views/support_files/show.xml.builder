xml.support_file(:id => @support_file.id, :content_type => @support_file.content_type) do
  xml.filename(@support_file.filename)
  xml.size(@support_file.size)
end
