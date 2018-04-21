class ResourceDownload < ResourceFile
  belongs_to :text_resource, foreign_key: :owner_id, touch: true
  has_one :upload_translation
  has_one :resource_download_stat, dependent: :destroy
end
