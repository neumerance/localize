module CmsActions
  class ReleaseToTranslator
    def call(cms_request:)
      cms_request.cms_target_languages.each do |cms_target_language|
        wc = cms_request.base_xliff.parsed_xliff.tm_word_count

        cms_target_language.word_count = wc
        cms_target_language.money_account = cms_request.website.client.find_or_create_account(DEFAULT_CURRENCY_ID)
        cms_target_language.save!
      end

      revision = cms_request.revision
      revision.update_attributes!(
        description: "Created by WebTA CMS update. This project is part of:\n#{revision.project.name}",
        project_completion_duration: 3, notified: 1
      )

      cms_request.update_attributes(
        status: CMS_REQUEST_RELEASED_TO_TRANSLATORS,
        pending_tas: false
      )
      cms_request
    end
  end
end
