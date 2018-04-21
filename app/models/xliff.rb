require 'xliffer'

class Xliff < ApplicationRecord
  belongs_to :cms_request
  has_one :parsed_xliff, dependent: :destroy
  has_many :xliff_trans_units, through: :parsed_xliff
  has_many :xliff_trans_unit_mrks
  attr_accessor :skip_parsing

  has_attachment storage: :file_system, max_size: XLIFF_MAX_SIZE.kilobytes, file_system_path: "private/#{Rails.env}/#{table_name}" # has_attachment

  include AttachmentFuOverrides
  include AttachmentAutoBackup

  def after_attachment_saved(_obj)
    BackupUploadJob.perform_later(self) if Rails.env.production?
    # TODO: remove this from callback
    create_parsed_xliff unless self.skip_parsing
  end

  validates_as_attachment

  def get_contents
    dat = StringIO.new(File.read(full_filename))
    gz = Zlib::GzipReader.new(dat)
    gz.read
  rescue Zlib::GzipFile::Error
    File.read(full_filename)
  end

  def set_contents(plain_contents)
    Zlib::GzipWriter.open(full_filename) do |gz|
      gz.write(plain_contents)
    end
    self.size = File.size(full_filename)
    save!
  end

  def translated?
    translated
  end

  def untranslated?
    !translated?
  end

  def to_html
    html_output = '<html><head><title></title>'
    html_output += '<meta http-equiv="Content-Type" content="text/html; charset=utf-8" /></head>' + "\n"
    html_output += "<body>\n"

    xliffer = XLIFFer::XLIFF.new get_contents

    xliffer.files.each do |file|
      html_output += "<h2>#{file.original}</h2>"
      file.strings.each do |string|
        html_output += "<h3>#{string.id}</h3>\n<h4>Original</h4>\n#{string.source}\n<h4>Translation</h4>\n#{string.target}\n<hr />"
      end
      html_output += '<hr />'
    end
    html_output += "</body>\n</html>\n"

    html_output
  end

  def preview
    output = ''
    xliffer = XLIFFer::XLIFF.new get_contents
    xliffer.files.each do |file|
      output += "\n-------------------------------------------\n"
      output += file.original.to_s
      file.strings.each do |string|
        output += "\n      ******\n"
        output += "\nOriginal\n#{string.source}\n\nTranslation\n#{string.target}\n"
      end
    end

    output
  end

  # this method is used only to check if a parsed_xliff is required
  def needs_processing?
    self.untranslated? && self.try(:cms_request).try(:cms_target_language).try(:language) && !self.processed
  end

  # This method is NOT used in ICL, to learn more about how word_count works
  # go to cms_request.rb
  # This method is created only to use from console and it NOT used by system
  def count_words(ignore_shortcode = false)
    word_count = 0
    asian_language = cms_request.cms_target_language.language.is_asian?
    nbsp = sprintf('%c', 0xC2) + sprintf('%c', 0xA0)

    xliffer = XLIFFer::XLIFF.new get_contents
    xliffer.files.each do |file|
      file.strings.each do |string|
        if ignore_shortcode
          string.source = string.source.gsub(/\[(.+?)\]/, ' ').gsub(/ +/, ' ').strip
        end

        # Remove HTML Tags (@ToDo what about title and alt attributes?)
        string.source = ActionView::Base.full_sanitizer.sanitize string.source

        word_count += if asian_language
                        (string.source.gsub(nbsp, ' ').tr('/', ' ').length / UTF8_ASIAN_WORDS).ceil
                      else
                        string.source.gsub(nbsp, ' ').tr('/', ' ').split.length
                      end
      end
    end

    word_count
  end

  # Fix for xliff that was uploaded without <?xml definition
  #   https://onthegosystems.myjetbrains.com/youtrack/issue/iclsupp-583
  def fix_xml_header
    content = get_contents
    update = false

    unless content =~ /<?xml version/
      content = '<?xml version="1.0" encoding="utf-8" standalone="no"?>' + content
      update = true
    end
    if content.include? '<xliff version="1.2">'
      content.gsub! '<xliff version="1.2">', '<xliff xmlns="urn:oasis:names:tc:xliff:document:1.2" version="1.2">'
      update = true
    end

    set_contents content if update
  end

  def create_parsed_xliff
    if needs_processing?
      Rails.logger.info("[#{self.class.name}##{__callee__}] requesting_parsed_xliff_creation_for_cms_request #{cms_request&.id}")
    else
      Rails.logger.info("[#{self.class.name}##{__callee__}] skipped_for_cms_request #{cms_request&.id}")
      return
    end
    ParsedXliff.create_parsed_xliff_by_id(self.id)
  end

  def create_new_parsed_xliff
    ParsedXliff.create_parsed_xliff(self)
  end

  def mrks
    xliff_trans_unit_mrks
  end

  def units
    xliff_trans_units
  end

  class NotTranslated < JSONError
    def initialize
      @code = XLIFF_NOT_TRANSLATED
      @message = "Can't find a translated XLIFF for this cms_request"
    end
  end
end
