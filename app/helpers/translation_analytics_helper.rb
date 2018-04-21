module TranslationAnalyticsHelper
  include TranslationAnalyticsBaseHelper
  def present_pair(language_pair)
    link_to(
      _('From <strong>%s</strong> to <strong>%s</strong>') % [language_pair.from_language.name, language_pair.to_language.name],
      '#'
    )
  end

  def progress_graph_reload_link(progress_graph_link, estimates)
    param = {
      'language_pair_id' => { data: "jQuery('#selected_language_pair_id').val()", mode: 'javascript' },
      'estimates' => { data: estimates, mode: 'html' }
    }
    param = param.map do |k, v|
      if v[:mode] == 'javascript'
        k + '=' + "'+#{v[:data]}+'"
      else
        k + '=' + (v[:data]).to_s
      end
    end
    "#{progress_graph_link}&#{param.join('&')}'"
  end

end
