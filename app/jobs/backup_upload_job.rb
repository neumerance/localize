class BackupUploadJob < ApplicationJob
  queue_as :backup_upload_to_s3

  def perform(object)
    object.send_to_s3
  end

  rescue_from(ActiveJob::DeserializationError) do |exception|
    Rails.logger.error "#{exception} #{exception.message}"
    true
  end

  def max_attempts
    1
  end
end
