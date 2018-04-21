require 'zlib'
require 'fileutils'
require 'stringio'
require 'fileutils'

class ZippedFile < ApplicationRecord
  belongs_to :normal_user, foreign_key: :by_user_id

  has_attachment storage: :file_system, max_size: ZIPPED_FILE_MAX_SIZE.kilobytes, path_prefix: "private/#{Rails.env}/#{table_name}"
  validates_as_attachment

  include AttachmentFuOverrides
  include AttachmentAutoBackup

  def after_attachment_saved(obj)
    obj = self
    unless %w(ResourceUpload ResourceTranslation).include?(obj.class.to_s)
      obj.do_zip unless obj.zipped?
      BackupUploadJob.perform_later(self)
    end
  end

  def zipped?
    filename.length > 3 && (filename[-3..-1] == '.gz')
  end

  def initialize(params = nil)
    super(params)
    self.chgtime = Time.now
    self.status = 1 # So far we are only using status for resource_uploads
  end

  def get_contents
    raise Errno::ENOENT unless current_data
    dat = StringIO.new(current_data)
    gz = Zlib::GzipReader.new(dat)
    gz.read
  rescue Errno::ENOENT, Zlib::GzipFile::Error => e
    Rails.logger.info "##########   #{e.class.name}   #########"
    Rails.logger.error e
    Rails.logger.error e.backtrace.join("\n")
    return nil
  end

  def do_zip
    res = StringIO.new('wb')
    gz = Zlib::GzipWriter.new(res)
    gz.write current_data
    gz.close

    File.file?(full_filename) ? File.open(full_filename, 'w').write(res.string) : nil

    # Don't change the filename before compressing because the current_data method read from that file
    # if file doesn't exists it returns nil.
    self.filename = filename + '.gz'
    self.size = res.length
    save!
  end

  def orig_filename
    if filename.length < 3
      filename
    elsif filename[-3..-1] == '.gz'
      filename[0..-4]
    else
      filename
    end
  end

  # TODO: Does this belongs here?
  def self.extensions
    %w(.pdf .doc .docx .xls .xlsx .odt .ods .rtf .txt .csv)
  end

  def self.spreadsheet_extension?(ext)
    %w(.xls .xlsx .ods .csv).include?(ext.downcase)
  end

  def self.format_name_for(extension)
    case extension.downcase
    when '.pdf'
      'PDF file'
    when '.doc', '.docx'
      'Microsoft Word file'
    when '.xls', '.xlsx'
      'Microsoft Excel file'
    when '.odt'
      'Libreoffice Word file'
    when '.ods'
      'Libreoffice Calc file'
    when '.rtf'
      'Rich Text file'
    when '.txt'
      'Plain Text file'
    when '.csv'
      'Coma-separated values'
    else
      raise "unknown extension #{extension}"
    end
  end

  def text
    if ZippedFile.extensions.include?(File.extname(orig_filename))
      # TODO: Do this in memory?
      file = Tempfile.new(filename)
      file.write(temp_data)
      file.close
      path = file.path
      output_path = "#{path}-output"
      text = Docsplit.extract_text(path, output: output_path)
      file.unlink

      output_text = File.read(Dir[output_path + '/*'][0])

      output_text.split_text.join(' ')
    else
      raise 'unknown file type'
    end
  rescue Docsplit::ExtractionFailed => e
    if e.to_s =~ /libcdr::EndOfStreamException/ # libreoffice error - empty file
      ''
    else
      raise
    end
  end
end
