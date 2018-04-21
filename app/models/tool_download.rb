class ToolDownload < ZippedFile
  def accesskey
    Digest::MD5.hexdigest(id.to_s + 'sdfs0df98lkj3')
  end

  def set_contents(plain_contents)
    FileUtils.mkdir_p(File.dirname(full_filename))

    Zlib::GzipWriter.open(full_filename) do |gz|
      gz.write(plain_contents)
    end

    self.size = File.size(full_filename)
    save!
    send_to_s3
  end
end
