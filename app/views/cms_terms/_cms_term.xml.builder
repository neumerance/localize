xml.cms_term(:id=>cms_term.id, :kind=>cms_term.kind, :txt=>cms_term.txt, :cms_identifier=>cms_term.cms_identifier, :language_id=>cms_term.language_id) do
	logger.debug kind.inspect
	logger.debug show_translation.inspect
	logger.debug show_children.inspect
	logger.debug cms_term.children_by_kind(kind).inspect
	if show_children
		xml.children do
			xml << render(:partial=>'cms_term', :collection=>cms_term.children_by_kind(kind), :locals => {:kind=>kind, :show_children=>show_children, :show_translation=>show_translation}).to_s
		end
	end
	if show_translation
		xml.translations do
			cms_term.cms_term_translations.each do |translation|
				xml.translation(:id=>translation.id, :language_id=>translation.language_id, :status=>translation.status,
								:txt=>translation.txt, :cms_identifier=>translation.cms_identifier)
			end
		end
	end
end
