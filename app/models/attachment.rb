class Attachment < ApplicationRecord
  belongs_to :message

  has_attachment storage: :file_system, max_size: ATTACHMENT_MAX_SIZE.kilobytes, file_system_path: "private/#{Rails.env}/#{table_name}"

  include AttachmentFuOverrides
  include AttachmentAutoBackup

  def after_attachment_saved(_obj)
    BackupUploadJob.perform_later(self)
  end

  validates_as_attachment

  def is_image?
    ['image/jpeg', 'image/jpg', 'image/png', 'image/gif', 'image/x-ms-bmp'].include? content_type
  end

end
