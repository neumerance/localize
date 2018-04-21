class Image < ApplicationRecord
  has_attachment storage: :file_system, max_size: IMAGE_MAX_SIZE.kilobytes, content_type: :image, file_system_path: "#{PHOTO_PATH}/#{table_name}/#{Rails.env}"

  include AttachmentFuOverrides
  include AttachmentAutoBackup

  belongs_to :owner, polymorphic: true

  validates_as_attachment

  def after_attachment_saved(_obj)
    BackupUploadJob.perform_later(self)
  end
end
