xml.pending_cms_requests do
	@pending_cms_requests.each do |cms_request|
		xml.cms_request(:id=>cms_request.id, :status=>cms_request.status, :website_id=>cms_request.website_id, :language_id=>cms_request.language_id)
	end
end