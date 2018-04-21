class ResourceFile < ZippedFile
  belongs_to :text_resource, foreign_key: :owner_id
  belongs_to :user, foreign_key: :by_user_id

  after_save :touch_text_resource

  def set_contents(plain_contents)
    FileUtils.mkdir_p(File.dirname(full_filename))

    Zlib::GzipWriter.open(full_filename) do |gz|
      gz.write(plain_contents)
    end

    self.size = File.size(full_filename)
    save!
  end

  private
  def touch_text_resource
    self.text_resource.touch
  end

end
