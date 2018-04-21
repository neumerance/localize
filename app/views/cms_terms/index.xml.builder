xml.cms_terms do
	xml << render(:partial=>'cms_term', :collection=>@cms_terms, :locals => {:kind=>@kind, :show_children=>@show_children, :show_translation=>@show_translation}).to_s
end
