module Queries
  module CmsRequests
    module WebtaTool
      class ParentRequests
        def call(cms:)
          attrs = cms.attributes.slice('language_id', 'website_id', 'cms_id')
          records = CmsRequest.
                    includes(revision: { versions: :user }).
                    where(attrs.merge(status: [CMS_REQUEST_DONE, CMS_REQUEST_TRANSLATED])).
                    where('id < ?', cms.id).
                    order(id: :desc).to_a

          records.reject do |parent_cms|
            parent_cms.revision&.versions&.select { |v| v.user&.type == 'Translator' }&.last
          end
        end
      end
    end
  end
end
