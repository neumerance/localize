
#   CmsDownload are created on wpml 3.1 version, is uploaded by TAS.
class CmsDownload < ZippedFile
  belongs_to :cms_target_language, foreign_key: :owner_id
  belongs_to :user, foreign_key: :by_user_id

  def to_html
    doc = REXML::Document.new(get_contents)

    fields = {}
    doc.elements.each('cms_request_details/contents/content') do |entry|
      original = entry.attributes['data']
      next unless original && (entry.attributes['translate'].to_i == 1)
      entry.elements.each('translations/translation') do |translation|
        if translation.attributes['lang'] == cms_target_language.language.name && translation.attributes['data']
          fields[entry.attributes['type']] = [Base64.decode64(original), Base64.decode64(translation.attributes['data'])]
        end
      end
    end

    html_output = '<html><head><title>' + (fields.key?('title') ? fields['title'][1] : 'no title') + '</title>'
    html_output += '<meta http-equiv="Content-Type" content="text/html; charset=utf-8" /></head>' + "\n"
    html_output += "<body>\n"
    fields.each { |k, v| html_output += "<h2>#{k}</h2>\n<h3>Original</h3>\n#{v[0]}\n<h3>Translation</h3>\n#{v[1]}\n<hr />" }
    html_output += "</body>\n</html>\n"

    html_output
  end
end
