xml.tus do
	@tus.each do |signature,tu|
		xml.tu(tu.translation, :signature=>tu.signature, :to_language_id=>tu.to_language_id, :status=>tu.status)
	end
end