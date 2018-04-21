xml.website(:id=>@website.id, :name=>@website.name, :description=>@website.description, :url=>@website.url,
		:login=>@website.login, :password=>@website.password, :blogid=>@website.blogid, :platform_kind=>@website.platform_kind,
		:pickup_type=>@website.pickup_type, :accesskey=>@website.accesskey,
		:interview_translators=>@website.interview_translators,
		:free_usage=>@website.free_usage, :project_kind=>@website.project_kind, :support_ticket_id=>@support_ticket_id,
		:xmlrpc_path=>@website.xmlrpc_path) do
	xml.client(:id=>@website.client.id, :fname=>@website.client.fname, :lname=>@website.client.lname, :balance=>@balance, :userstatus=>@website.client.userstatus, :email=>@website.client.email, :anon=>@website.client.anon)
	xml.translation_languages do
		@website.website_translation_offers.where('status!=?',TRANSLATION_OFFER_SUSPENDED).each do |website_translation_offer|
			xml.translation_language(:id=>website_translation_offer.id,
							:status=>website_translation_offer.status,
							:from_language_name=>website_translation_offer.from_language.name, :from_language_id=>website_translation_offer.from_language_id,
							:to_language_name=>website_translation_offer.to_language.name, :to_language_id=>website_translation_offer.to_language_id,
							:url=>website_translation_offer.url, :login=>website_translation_offer.login, :password=>website_translation_offer.password, :blogid=>website_translation_offer.blogid,
							:have_translators=> website_translation_offer.have_translators,
							:applications=>website_translation_offer.applied_website_translation_contracts.count,
							:available_translators=>website_translation_offer.available_translators,
							:contract_id=>website_translation_offer.first_accepted_contract_id) do
				xml.translators do
					website_translation_offer.accepted_website_translation_contracts.each do |website_translation_contract|
						xml.translator(:id=>website_translation_contract.translator.id, :nickname=>website_translation_contract.translator.nickname, :amount=>website_translation_contract.amount, :contract_id=>website_translation_contract.id)
					end
				end
			end
		end
	end
	if @unfunded_requests && (@unfunded_requests.length > 0)
		xml.unfunded_cms_requests(:missing_funds=>@missing_funds) do
			@unfunded_requests.each do |cms_request_info|
				xml.cms_request(:id=>cms_request_info[0].id, :language=>cms_request_info[0].language.name, :language_id=>cms_request_info[0].language_id) do
					cms_request_info[0].cms_target_languages.each do |cms_target_language|
						xml.cms_target_language(:id=>cms_target_language.id, :language=>cms_target_language.language.name, :word_count=>cms_target_language.word_count, :language_id=>cms_target_language.language_id)
					end
				end
			end
		end
	end
	xml.html_status(project_status_for_xml())
	xml.translators_management_info(translators_management_info_for_xml())
end
