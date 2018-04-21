class Download < ApplicationRecord
  has_attachment storage: :file_system, max_size: DOWNLOAD_MAX_SIZE.kilobytes, file_system_path: "private/#{Rails.env}/#{table_name}"

  include AttachmentFuOverrides
  include AttachmentAutoBackup

  def after_attachment_saved(_obj)
    BackupUploadJob.perform_later(self)
  end

  validates_as_attachment
  validates_presence_of :generic_name, :major_version, :sub_version
  validates_numericality_of :major_version, :sub_version
  validates_inclusion_of :usertype, in: %w(Client Translator)
  validates :notes, length: { maximum: COMMON_FIELD }

  has_many :user_downloads, dependent: :destroy
  has_many :users, through: :user_downloads

  def initialize(params = nil)
    super(params)
    self.create_time = Time.now
  end

end
