require 'rubygems/package'

module AttachmentAutoBackup
  def send_to_s3
    return true unless Rails.env.production?

    return unless File.exist?(full_filename)
    crypto = GPGME::Crypto.new
    crypted_content = crypto.encrypt relative_path_tarball, recipients: Figaro.env.GPGME_KEY, always_trust: true
    object_name = "#{self.class}_#{id}"
    bucket = Figaro.env.aws_s3_bucket

    BackupSender.send(bucket, object_name, crypted_content.read, content_type: 'binary/octet-stream')
    Logging.log(self, id: self.id, klass: self.class)
    update_attribute(:backup_on_s3, true)
  end

  def relative_path_tarball
    mode_644 = 33188

    path_levels = full_filename.gsub(/#{Rails.root}\//, '').split('/')
    path_levels[-1] = "#{self.class.name}_#{id}.gz"
    relative_filename = path_levels.join('/')

    tarball = StringIO.new
    tar_writter = Gem::Package::TarWriter.new(tarball)
    tar_writter.add_file(relative_filename, mode_644) do |tf|
      tf.write File.open(full_filename, 'rb').read
    end
    tarball.rewind
    tarball
  end
end
