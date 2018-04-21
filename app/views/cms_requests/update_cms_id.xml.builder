xml.updated do
	@cms_requests.each do |cms_request|
		xml.cms_request(:id=>cms_request.id, :cms_id=>cms_request.cms_id)
	end
end