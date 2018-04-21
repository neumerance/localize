class CmsCount < ApplicationRecord
  belongs_to :cms_count_group
  belongs_to :website_translation_offer
end
