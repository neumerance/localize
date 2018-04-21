xml.cms_request(:id=>@cms_request.id, :cms_id=>@cms_request.cms_id, :status=>@cms_request.status, :revision_id=>@revision_id, :project_id=>@project_id, :website_id=>@cms_request.website_id, :language_id=>@cms_request.language_id, :language_name => @cms_request.language.name, :title=>@cms_request.title, :permlink=>@cms_request.permlink, :list_type=>@cms_request.list_type, :list_id=>@cms_request.list_id, :created_at=>@cms_request.created_at.to_i, :updated_at=>@cms_request.updated_at.to_i, :last_operation=>@cms_request.last_operation, :pending_tas=>@cms_request.pending_tas, :container=>@cms_request.container, :tp_id=>@cms_request.tp_id) do
  xml.cms_uploads do
    @cms_request.cms_uploads.each do |cms_upload|
      xml.cms_upload(:id=>cms_upload.id, :content_type=>cms_upload.content_type) do
        xml.filename(cms_upload.filename)
        xml.description(cms_upload.description)
        xml.size(cms_upload.size)
        xml.created_by(:id=>cms_upload.user.try(:id), :type=>cms_upload.user.try(:type), :name=>cms_upload.user.try(:full_name))
        xml.modified(cms_upload.chgtime.to_i)
      end
    end
  end
  xml.cms_target_languages do
    @cms_request.cms_target_languages.each do |cms_target_language|
      xml.cms_target_language(:id=>cms_target_language.id, :language_id=>cms_target_language.language_id, :language=>cms_target_language.language.name, :status=>cms_target_language.status, :title=>cms_target_language.title, :permlink=>cms_target_language.permlink, :word_count=>cms_target_language.word_count, :translator_id=>cms_target_language.translator_id) do
        if cms_target_language.translator
          xml.translator(:id=>cms_target_language.translator.id, :nickname=>cms_target_language.translator.full_name)
        end
        xml.cms_downloads do
          cms_target_language.cms_downloads.each do |cms_download|
            xml.cms_download(:id=>cms_download.id, :content_type=>cms_download.content_type) do
              xml.filename(cms_download.filename)
              xml.description(cms_download.description)
              xml.size(cms_download.size)
              xml.created_by(:id=>cms_download.user.id, :type=>cms_download.user[:type], :name=>cms_download.user.full_name)
              xml.modified(cms_download.chgtime.to_i)
            end
          end
        end
      end
    end
  end
  xml.cms_request_metas do
    @cms_request.cms_request_metas.each do |cms_request_meta|
      xml.cms_request_meta(cms_request_meta.value, :name=>cms_request_meta.name)
    end
  end

  xml.shortcodes do
    @cms_request.website.enabled_shortcodes.each do |shortcode|
      xml.shortcode(shortcode.shortcode, :content_type => shortcode.content_type)
    end
  end
end
