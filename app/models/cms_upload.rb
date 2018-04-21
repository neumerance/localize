require 'base64'
require 'nokogiri'

#   CmsUpload are created on wpml 3.1 version and is a XTA format, are not created
#   with TP.
class CmsUpload < ZippedFile
  belongs_to :cms_request, foreign_key: :owner_id
  belongs_to :user, foreign_key: :by_user_id

  def body_data
    gz = Zlib::GzipReader.open(full_filename)
    file = Nokogiri::XML(gz.read)
    puts file.inspect
    body_data = file.css('cms_request_details contents content[type=body]').attr('data').value
    Base64.decode64(body_data)
  end

end
