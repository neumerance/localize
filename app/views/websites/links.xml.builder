xml.link_map do
	@link_map.each do |k,v|
		xml.original(:url=>k.permlink, :title=>k.title) do
			v.each do |lang_id,trans|
				xml.translation(:lang_id=>lang_id, :url=>trans[0], :title=>trans[1])
			end
		end
	end
end