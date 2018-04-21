xml.cms_download(:id=>@cms_download.id, :content_type=>@cms_download.content_type) do
	xml.filename(@cms_download.filename)
	xml.description(@cms_download.description)
	xml.size(@cms_download.size)
	xml.created_by(:id=>@cms_download.user.id, :type=>@cms_download.user[:type], :name=>@cms_download.user.full_name)
	xml.modified(@cms_download.chgtime.to_i)
end
