def self.up
  lang = Language.where('name = ?', 'English').first
  lang.update_attributes!(iso: 'en') if lang

  lang = Language.where('name = ?', 'Spanish').first
  lang.update_attributes!(iso: 'es') if lang

  lang = Language.where('name = ?', 'German').first
  lang.update_attributes!(iso: 'de') if lang

  lang = Language.where('name = ?', 'French').first
  lang.update_attributes!(iso: 'fr') if lang

  lang = Language.where('name = ?', 'Arabic').first
  lang.update_attributes!(iso: 'ar') if lang

  lang = Language.where('name = ?', 'Bosnian').first
  lang.update_attributes!(iso: 'bs') if lang

  lang = Language.where('name = ?', 'Bulgarian').first
  lang.update_attributes!(iso: 'bg') if lang

  lang = Language.where('name = ?', 'Catalan').first
  lang.update_attributes!(iso: 'ca') if lang

  lang = Language.where('name = ?', 'Czech').first
  lang.update_attributes!(iso: 'cs') if lang

  lang = Language.where('name = ?', 'Slavic').first
  lang.update_attributes!(iso: 'cu') if lang

  lang = Language.where('name = ?', 'Welsh').first
  lang.update_attributes!(iso: 'cy') if lang

  lang = Language.where('name = ?', 'Danish').first
  lang.update_attributes!(iso: 'da') if lang

  lang = Language.where('name = ?', 'Greek').first
  lang.update_attributes!(iso: 'el') if lang

  lang = Language.where('name = ?', 'Esperanto').first
  lang.update_attributes!(iso: 'eo') if lang

  lang = Language.where('name = ?', 'Estonian').first
  lang.update_attributes!(iso: 'et') if lang

  lang = Language.where('name = ?', 'Basque').first
  lang.update_attributes!(iso: 'eu') if lang

  lang = Language.where('name = ?', 'Persian').first
  lang.update_attributes!(iso: 'fa') if lang

  lang = Language.where('name = ?', 'Finnish').first
  lang.update_attributes!(iso: 'fi') if lang

  lang = Language.where('name = ?', 'Irish').first
  lang.update_attributes!(iso: 'ga') if lang

  lang = Language.where('name = ?', 'Hebrew').first
  lang.update_attributes!(iso: 'he') if lang

  lang = Language.where('name = ?', 'Hindi').first
  lang.update_attributes!(iso: 'hi') if lang

  lang = Language.where('name = ?', 'Croatian').first
  lang.update_attributes!(iso: 'hr') if lang

  lang = Language.where('name = ?', 'Hungarian').first
  lang.update_attributes!(iso: 'hu') if lang

  lang = Language.where('name = ?', 'Armenian').first
  lang.update_attributes!(iso: 'hy') if lang

  lang = Language.where('name = ?', 'Indonesian').first
  lang.update_attributes!(iso: 'id') if lang

  lang = Language.where('name = ?', 'Icelandic').first
  lang.update_attributes!(iso: 'is') if lang

  lang = Language.where('name = ?', 'Italian').first
  lang.update_attributes!(iso: 'it') if lang

  lang = Language.where('name = ?', 'Japanese').first
  lang.update_attributes!(iso: 'ja') if lang

  lang = Language.where('name = ?', 'Korean').first
  lang.update_attributes!(iso: 'ko') if lang

  lang = Language.where('name = ?', 'Kurdish').first
  lang.update_attributes!(iso: 'ku') if lang

  lang = Language.where('name = ?', 'Latin').first
  lang.update_attributes!(iso: 'la') if lang

  lang = Language.where('name = ?', 'Latvian').first
  lang.update_attributes!(iso: 'lv') if lang

  lang = Language.where('name = ?', 'Lithuanian').first
  lang.update_attributes!(iso: 'lt') if lang

  lang = Language.where('name = ?', 'Macedonian').first
  lang.update_attributes!(iso: 'mk') if lang

  lang = Language.where('name = ?', 'Maltese').first
  lang.update_attributes!(iso: 'mt') if lang

  lang = Language.where('name = ?', 'Moldavian').first
  lang.update_attributes!(iso: 'mo') if lang

  lang = Language.where('name = ?', 'Mongolian').first
  lang.update_attributes!(iso: 'mn') if lang

  lang = Language.where('name = ?', 'Nepali').first
  lang.update_attributes!(iso: 'ne') if lang

  lang = Language.where('name = ?', 'Dutch').first
  lang.update_attributes!(iso: 'nl') if lang

  lang = Language.where('name = ?', 'Norwegian').first
  lang.update_attributes!(iso: 'nb') if lang

  lang = Language.where('name = ?', 'Panjabi').first
  lang.update_attributes!(iso: 'pa') if lang

  lang = Language.where('name = ?', 'Polish').first
  lang.update_attributes!(iso: 'pl') if lang

  lang = Language.where('name = ?', 'Portuguese').first
  lang.update_attributes!(iso: 'pt-BR') if lang

  lang = Language.where('name = ?', 'Quechua').first
  lang.update_attributes!(iso: 'qu') if lang

  lang = Language.where('name = ?', 'Romanian').first
  lang.update_attributes!(iso: 'ro') if lang

  lang = Language.where('name = ?', 'Russian').first
  lang.update_attributes!(iso: 'ru') if lang

  lang = Language.where('name = ?', 'Slovenian').first
  lang.update_attributes!(iso: 'sl') if lang

  lang = Language.where('name = ?', 'Somali').first
  lang.update_attributes!(iso: 'so') if lang

  lang = Language.where('name = ?', 'Albanian').first
  lang.update_attributes!(iso: 'sq') if lang

  lang = Language.where('name = ?', 'Serbian').first
  lang.update_attributes!(iso: 'sr') if lang

  lang = Language.where('name = ?', 'Swedish').first
  lang.update_attributes!(iso: 'sv') if lang

  lang = Language.where('name = ?', 'Tamil').first
  lang.update_attributes!(iso: 'ta') if lang

  lang = Language.where('name = ?', 'Thai').first
  lang.update_attributes!(iso: 'th') if lang

  lang = Language.where('name = ?', 'Turkish').first
  lang.update_attributes!(iso: 'tr') if lang

  lang = Language.where('name = ?', 'Ukrainian').first
  lang.update_attributes!(iso: 'uk') if lang

  lang = Language.where('name = ?', 'Urdu').first
  lang.update_attributes!(iso: 'ur') if lang

  lang = Language.where('name = ?', 'Uzbek').first
  lang.update_attributes!(iso: 'uz') if lang

  lang = Language.where('name = ?', 'Vietnamese').first
  lang.update_attributes!(iso: 'vi') if lang

  lang = Language.where('name = ?', 'Yiddish').first
  lang.update_attributes!(iso: 'yi') if lang

  lang = Language.where('name = ?', 'Chinese (Simplified)').first
  lang.update_attributes!(iso: 'zh-Hans') if lang

  lang = Language.where('name = ?', 'Zulu').first
  lang.update_attributes!(iso: 'zu') if lang

  lang = Language.where('name = ?', 'Chinese (Traditional)').first
  lang.update_attributes!(iso: 'zh-Hant') if lang

  lang = Language.where('name = ?', 'Portugal Portuguese').first
  lang.update_attributes!(iso: 'pt-PT') if lang

end

def self.down
end
