xml.cms_requests do
	@cms_requests.each do |cms_request|
		xml.cms_request(:id=>cms_request.id, :status=>cms_request.status, :language_id=>cms_request.language_id, :list_type=>cms_request.list_type, :list_id=>cms_request.list_id, :created_at=>cms_request.created_at.to_i, :updated_at=>cms_request.updated_at.to_i)
	end
end