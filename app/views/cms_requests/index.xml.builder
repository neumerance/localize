xml.pending_cms_requests do
	@cms_requests.each do |cms_request|
		if @show_languages
			xml.cms_request(:id=>cms_request.id, :cms_id=>cms_request.cms_id, :status=>cms_request.status, :website_id=>cms_request.website_id, :language_id=>cms_request.language_id, :list_type=>cms_request.list_type, :list_id=>cms_request.list_id, :created_at=>cms_request.created_at.to_i, :updated_at=>cms_request.updated_at.to_i, :container=>cms_request.container, :language_name=>cms_request.language.name) do
				cms_request.cms_target_languages.each do |ctl|
					xml.target_language(:id=>ctl.id, :language_id=>ctl.language_id, :language_name=>ctl.language.name, :status=>ctl.status)
				end
			end
		else
			xml.cms_request(:id=>cms_request.id, :cms_id=>cms_request.cms_id, :status=>cms_request.status, :website_id=>cms_request.website_id, :language_id=>cms_request.language_id, :list_type=>cms_request.list_type, :list_id=>cms_request.list_id, :created_at=>cms_request.created_at.to_i, :updated_at=>cms_request.updated_at.to_i, :container=>cms_request.container, :language_name=>cms_request.language.name)
		end
	end
end