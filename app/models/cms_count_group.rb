class CmsCountGroup < ApplicationRecord
  belongs_to :website
  has_many :cms_counts, dependent: :destroy
end
