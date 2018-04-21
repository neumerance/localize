module ResourceTranslationsHelper
  def reuse_translations_preview_strings_table(resource_strings)
    res = [infotab_header(['Label', 'New translation', 'Status', 'Current translation'])]
    resource_strings.each do |resource_string|
      res << "<tr><td>#{pre_format(resource_string[:token])}</td><td>#{pre_format(resource_string[:translation])}</td>"
      res << "<td style=\"background-color: #{ResourceTranslationsController::STRING_TRANSLATION_COLOR_CODE[resource_string[:status]]};\">#{ResourceTranslationsController::STRING_TRANSLATION_TEXT[resource_string[:status]].gsub(' ', '&nbsp;')}</td>"
      res << "<td>#{pre_format(resource_string[:current])}</td></tr>"
    end
    res << ['</table>']
    res.join.html_safe
  end
end
