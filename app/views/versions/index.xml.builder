if @versions
  xml.versions do
    for version in @versions
      xml.version(:id => version.id, :content_type => version.content_type) do
        xml.filename(version.filename)
        xml.size(version.size)
		xml.created_by(:id => version.user.id, :type => version.user[:type], :name => version.user.full_name)
		xml.modified(version.chgtime.to_i)
      end
    end
  end
end
