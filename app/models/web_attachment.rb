class WebAttachment < ApplicationRecord
  belongs_to :web_message

  has_attachment storage: :file_system, max_size: WEB_ATTACHMENT_MAX_SIZE.kilobytes, file_system_path: "private/#{Rails.env}/#{table_name}"

  include AttachmentFuOverrides
  include AttachmentAutoBackup

  validates_as_attachment

  def after_attachment_saved(_obj)
    BackupUploadJob.perform_later(self)
  end
end
