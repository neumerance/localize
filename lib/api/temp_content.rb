# this is used to build an object similar with a file upload
# to use this into a test or a model with attachment:
# instance = ModelWithAttachment.new
# instance.attachment_data = TempContent.new(path_to_file_to_attach, mime_type)
# if mime_type is not specified gzipped version of the file will be attached, else the normal file
class TempContent < StringIO

  def initialize(name, mime = 'application/gzip', content = nil)
    @filename = name
    @original_filename = name
    @content_type = mime
    @size = 1
    @content = content
    super(' ')
  end

  attr_reader :content_type, :size, :filename, :original_filename

  def read
    plain_contents = @content ? @content : File.read(@filename)
    return plain_contents unless @content_type == 'application/gzip'
    temp_file = Tempfile.new
    Zlib::GzipWriter.open(temp_file.path) do |gz|
      gz.write(plain_contents)
    end
    zipped_content = temp_file.read
    temp_file.unlink
    zipped_content
  end

end
