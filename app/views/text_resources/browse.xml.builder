xml.translations do
	if @resource_upload
		@resource_upload.resource_downloads.each do |resource_download|
			xml.translation(:language=>resource_download.upload_translation.language.name, :lang_code=>resource_download.upload_translation.language.iso,
				:completed=>(resource_download.resource_download_stat ? (100 * resource_download.resource_download_stat.completed / resource_download.resource_download_stat.total) : 0),
				:updated=>resource_download.chgtime.to_i) do
				xml.po(url_for({:only_path=>false, :controller=>:resource_downloads, :action=>:download, :text_resource_id=>resource_download.text_resource.id, :id=>resource_download.id}))
				if @look_for_mo
					xml.mo(url_for({:only_path=>false, :controller=>:resource_downloads, :action=>:download_mo, :text_resource_id=>resource_download.text_resource.id, :id=>resource_download.id}))
				end
			end
		end
	end
end