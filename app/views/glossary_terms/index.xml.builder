xml.glossary_terms do
	if @glossary_client && @glossary_client.glossary_terms
		@glossary_client.glossary_terms.each do |glossary_term|
			xml.glossary_term(:id=>glossary_term.id, :txt=>glossary_term.txt, :description=>glossary_term.description, :language=>glossary_term.language.name) do
				glossary_term.glossary_translations.each do |glossary_translation|
					xml.glossary_translation(:id=>glossary_translation.id, :language=>glossary_translation.language.name, :txt=>glossary_translation.txt)
				end
			end
		end
	end
end