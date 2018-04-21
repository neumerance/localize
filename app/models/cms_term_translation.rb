class CmsTermTranslation < ApplicationRecord
  belongs_to :language
  belongs_to :cms_term
end
