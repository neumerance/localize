if @download
	xml.download(:id=>@download.id) do
		xml.version(:major=>@download.major_version, :sub=>@download.sub_version)
		xml.size(@download.size)
		xml.filename(@download.filename)
		xml.create_time(@download.create_time.to_i)
	end
end