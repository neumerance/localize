class ResourceTranslation < ResourceFile
  belongs_to :text_resource, foreign_key: :owner_id, touch: true
end
