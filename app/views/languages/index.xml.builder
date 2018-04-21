xml.languages do
	for language in @languages
		xml.language(:eng_name => language.name, :code => language.iso, :id=>language.id, :rtl=>language.rtl) do
			xml.name(language.name)
		end
	end
end
