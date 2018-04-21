class ResourceStat < ApplicationRecord
  belongs_to :text_resource, touch: true
  belongs_to :resource_language, touch: true
end
