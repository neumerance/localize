xml.cms_container(:id => @cms_container.id, :content_type => @cms_container.content_type) do
	xml.filename(@cms_container.filename)
	xml.size(@cms_container.size)
	xml.created_by(:id => @cms_container.user.id, :type => @cms_container.user[:type], :name => @cms_container.user.full_name)
	xml.modified(@cms_container.chgtime.to_i)
end
