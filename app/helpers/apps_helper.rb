module AppsHelper
  def list_available_languages
    concat content_tag(:div) {
      res = []

      als = AvailableLanguage.includes(:to_language, :from_language)

      languages = {}
      als.each do |al|
        languages[al.from_language] = [] unless languages.key?(al.from_language)
        val = al.to_language.name
        unless languages[al.from_language].include?(val)
          languages[al.from_language] << val
        end
      end

      from_languages = languages.keys.collect { |l| [languages[l].length, l.name, l] }

      from_languages = from_languages.sort.reverse

      res << '<p>Translating from: ' + (from_languages.collect { |l| "<a href=\"#lang#{l[2].id}\">#{l[2].name}</a>" }).join(', ') + '</p>'

      from_languages.each do |l|
        lang = l[2]
        concat content_tag(:h3, lang.name, id: "lang#{lang.id}")
        concat content_tag(:p) {
          concat 'We can translate '.html_safe
          concat content_tag(:b, "from #{lang.name} "); concat 'to these languages:'.html_safe
        }
        concat content_tag(:ul) {
          languages[lang].sort.each do |k|
            concat content_tag(:li, k)
          end
        }
      end
    }
  end
end
