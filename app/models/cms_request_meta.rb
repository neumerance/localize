class CmsRequestMeta < ApplicationRecord
  self.table_name = 'cms_request_metas'

  belongs_to :cms_request
end
