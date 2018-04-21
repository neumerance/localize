class UploadTranslation < ApplicationRecord
  belongs_to :resource_upload
  belongs_to :resource_download
  belongs_to :language
end
