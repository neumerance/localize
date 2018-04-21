class ResourceUpload < ResourceFile
  belongs_to :text_resource, foreign_key: :owner_id, touch: true
  has_one :resource_upload_format, dependent: :destroy
  has_many :upload_translations, dependent: :destroy
  has_many :resource_downloads, through: :upload_translations

  def initialize(params = nil)
    super(params)
    self.status = 0
  end

  def all_translations_fname
    File.dirname(full_filename) + '/' + 'all_translations_for_%s.zip' % orig_filename
  end

  delegate :resource_format, to: :resource_upload_format

end
