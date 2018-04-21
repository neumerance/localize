class PopulateLanguages < ActiveRecord::Migration
def self.up
 lang = Language.where(["name = 'Arabic'"]).first
 if not lang
  Language.create(:name => "Arabic", :major => 0)
 else
  lang.major = 0
  lang.save!
 end

 lang = Language.where(["name = 'Bosnian'"]).first
 if not lang
  Language.create(:name => "Bosnian", :major => 0)
 else
  lang.major = 0
  lang.save!
 end

 lang = Language.where(["name = 'Bulgarian'"]).first
 if not lang
  Language.create(:name => "Bulgarian", :major => 0)
 else
  lang.major = 0
  lang.save!
 end

 lang = Language.where(["name = 'Catalan'"]).first
 if not lang
  Language.create(:name => "Catalan", :major => 0)
 else
  lang.major = 0
  lang.save!
 end

 lang = Language.where(["name = 'Czech'"]).first
 if not lang
  Language.create(:name => "Czech", :major => 0)
 else
  lang.major = 0
  lang.save!
 end

 lang = Language.where(["name = 'Slavic'"]).first
 if not lang
  Language.create(:name => "Slavic", :major => 0)
 else
  lang.major = 0
  lang.save!
 end

 lang = Language.where(["name = 'Welsh'"]).first
 if not lang
  Language.create(:name => "Welsh", :major => 0)
 else
  lang.major = 0
  lang.save!
 end

 lang = Language.where(["name = 'Danish'"]).first
 if not lang
  Language.create(:name => "Danish", :major => 1)
 else
  lang.major = 1
  lang.save!
 end

 lang = Language.where(["name = 'German'"]).first
 if not lang
  Language.create(:name => "German", :major => 1)
 else
  lang.major = 1
  lang.save!
 end

 lang = Language.where(["name = 'Greek'"]).first
 if not lang
  Language.create(:name => "Greek", :major => 0)
 else
  lang.major = 0
  lang.save!
 end

 lang = Language.where(["name = 'English'"]).first
 if not lang
  Language.create(:name => "English", :major => 1)
 else
  lang.major = 1
  lang.save!
 end

 lang = Language.where(["name = 'Esperanto'"]).first
 if not lang
  Language.create(:name => "Esperanto", :major => 0)
 else
  lang.major = 0
  lang.save!
 end

 lang = Language.where(["name = 'Estonian'"]).first
 if not lang
  Language.create(:name => "Estonian", :major => 0)
 else
  lang.major = 0
  lang.save!
 end

 lang = Language.where(["name = 'Basque'"]).first
 if not lang
  Language.create(:name => "Basque", :major => 0)
 else
  lang.major = 0
  lang.save!
 end

 lang = Language.where(["name = 'Persian'"]).first
 if not lang
  Language.create(:name => "Persian", :major => 0)
 else
  lang.major = 0
  lang.save!
 end

 lang = Language.where(["name = 'Finnish'"]).first
 if not lang
  Language.create(:name => "Finnish", :major => 0)
 else
  lang.major = 0
  lang.save!
 end

 lang = Language.where(["name = 'French'"]).first
 if not lang
  Language.create(:name => "French", :major => 1)
 else
  lang.major = 1
  lang.save!
 end

 lang = Language.where(["name = 'Irish'"]).first
 if not lang
  Language.create(:name => "Irish", :major => 0)
 else
  lang.major = 0
  lang.save!
 end

 lang = Language.where(["name = 'Hebrew'"]).first
 if not lang
  Language.create(:name => "Hebrew", :major => 0)
 else
  lang.major = 0
  lang.save!
 end

 lang = Language.where(["name = 'Hindi'"]).first
 if not lang
  Language.create(:name => "Hindi", :major => 0)
 else
  lang.major = 0
  lang.save!
 end

 lang = Language.where(["name = 'Croatian'"]).first
 if not lang
  Language.create(:name => "Croatian", :major => 0)
 else
  lang.major = 0
  lang.save!
 end

 lang = Language.where(["name = 'Hungarian'"]).first
 if not lang
  Language.create(:name => "Hungarian", :major => 0)
 else
  lang.major = 0
  lang.save!
 end

 lang = Language.where(["name = 'Armenian'"]).first
 if not lang
  Language.create(:name => "Armenian", :major => 0)
 else
  lang.major = 0
  lang.save!
 end

 lang = Language.where(["name = 'Indonesian'"]).first
 if not lang
  Language.create(:name => "Indonesian", :major => 0)
 else
  lang.major = 0
  lang.save!
 end

 lang = Language.where(["name = 'Icelandic'"]).first
 if not lang
  Language.create(:name => "Icelandic", :major => 0)
 else
  lang.major = 0
  lang.save!
 end

 lang = Language.where(["name = 'Italian'"]).first
 if not lang
  Language.create(:name => "Italian", :major => 1)
 else
  lang.major = 1
  lang.save!
 end

 lang = Language.where(["name = 'Japanese'"]).first
 if not lang
  Language.create(:name => "Japanese", :major => 1)
 else
  lang.major = 1
  lang.save!
 end

 lang = Language.where(["name = 'Korean'"]).first
 if not lang
  Language.create(:name => "Korean", :major => 0)
 else
  lang.major = 0
  lang.save!
 end

 lang = Language.where(["name = 'Kurdish'"]).first
 if not lang
  Language.create(:name => "Kurdish", :major => 0)
 else
  lang.major = 0
  lang.save!
 end

 lang = Language.where(["name = 'Latin'"]).first
 if not lang
  Language.create(:name => "Latin", :major => 0)
 else
  lang.major = 0
  lang.save!
 end

 lang = Language.where(["name = 'Latvian'"]).first
 if not lang
  Language.create(:name => "Latvian", :major => 0)
 else
  lang.major = 0
  lang.save!
 end

 lang = Language.where(["name = 'Lithuanian'"]).first
 if not lang
  Language.create(:name => "Lithuanian", :major => 0)
 else
  lang.major = 0
  lang.save!
 end

 lang = Language.where(["name = 'Macedonian'"]).first
 if not lang
  Language.create(:name => "Macedonian", :major => 0)
 else
  lang.major = 0
  lang.save!
 end

 lang = Language.where(["name = 'Maltese'"]).first
 if not lang
  Language.create(:name => "Maltese", :major => 0)
 else
  lang.major = 0
  lang.save!
 end

 lang = Language.where(["name = 'Moldavian'"]).first
 if not lang
  Language.create(:name => "Moldavian", :major => 0)
 else
  lang.major = 0
  lang.save!
 end

 lang = Language.where(["name = 'Mongolian'"]).first
 if not lang
  Language.create(:name => "Mongolian", :major => 0)
 else
  lang.major = 0
  lang.save!
 end

 lang = Language.where(["name = 'Nepali'"]).first
 if not lang
  Language.create(:name => "Nepali", :major => 0)
 else
  lang.major = 0
  lang.save!
 end

 lang = Language.where(["name = 'Dutch'"]).first
 if not lang
  Language.create(:name => "Dutch", :major => 1)
 else
  lang.major = 1
  lang.save!
 end

 lang = Language.where(["name = 'Norwegian'"]).first
 if not lang
  Language.create(:name => "Norwegian", :major => 0)
 else
  lang.major = 0
  lang.save!
 end

 lang = Language.where(["name = 'Panjabi'"]).first
 if not lang
  Language.create(:name => "Panjabi", :major => 0)
 else
  lang.major = 0
  lang.save!
 end

 lang = Language.where(["name = 'Polish'"]).first
 if not lang
  Language.create(:name => "Polish", :major => 0)
 else
  lang.major = 0
  lang.save!
 end

 lang = Language.where(["name = 'Portuguese'"]).first
 if not lang
  Language.create(:name => "Portuguese", :major => 1)
 else
  lang.major = 1
  lang.save!
 end

 lang = Language.where(["name = 'Quechua'"]).first
 if not lang
  Language.create(:name => "Quechua", :major => 0)
 else
  lang.major = 0
  lang.save!
 end

 lang = Language.where(["name = 'Romanian'"]).first
 if not lang
  Language.create(:name => "Romanian", :major => 0)
 else
  lang.major = 0
  lang.save!
 end

 lang = Language.where(["name = 'Russian'"]).first
 if not lang
  Language.create(:name => "Russian", :major => 1)
 else
  lang.major = 1
  lang.save!
 end

 lang = Language.where(["name = 'Slovenian'"]).first
 if not lang
  Language.create(:name => "Slovenian", :major => 0)
 else
  lang.major = 0
  lang.save!
 end

 lang = Language.where(["name = 'Somali'"]).first
 if not lang
  Language.create(:name => "Somali", :major => 0)
 else
  lang.major = 0
  lang.save!
 end

 lang = Language.where(["name = 'Spanish'"]).first
 if not lang
  Language.create(:name => "Spanish", :major => 1)
 else
  lang.major = 1
  lang.save!
 end

 lang = Language.where(["name = 'Albanian'"]).first
 if not lang
  Language.create(:name => "Albanian", :major => 0)
 else
  lang.major = 0
  lang.save!
 end

 lang = Language.where(["name = 'Serbian'"]).first
 if not lang
  Language.create(:name => "Serbian", :major => 0)
 else
  lang.major = 0
  lang.save!
 end

 lang = Language.where(["name = 'Swedish'"]).first
 if not lang
  Language.create(:name => "Swedish", :major => 0)
 else
  lang.major = 0
  lang.save!
 end

 lang = Language.where(["name = 'Tamil'"]).first
 if not lang
  Language.create(:name => "Tamil", :major => 0)
 else
  lang.major = 0
  lang.save!
 end

 lang = Language.where(["name = 'Thai'"]).first
 if not lang
  Language.create(:name => "Thai", :major => 0)
 else
  lang.major = 0
  lang.save!
 end

 lang = Language.where(["name = 'Turkish'"]).first
 if not lang
  Language.create(:name => "Turkish", :major => 0)
 else
  lang.major = 0
  lang.save!
 end

 lang = Language.where(["name = 'Ukrainian'"]).first
 if not lang
  Language.create(:name => "Ukrainian", :major => 0)
 else
  lang.major = 0
  lang.save!
 end

 lang = Language.where(["name = 'Urdu'"]).first
 if not lang
  Language.create(:name => "Urdu", :major => 0)
 else
  lang.major = 0
  lang.save!
 end

 lang = Language.where(["name = 'Uzbek'"]).first
 if not lang
  Language.create(:name => "Uzbek", :major => 0)
 else
  lang.major = 0
  lang.save!
 end

 lang = Language.where(["name = 'Vietnamese'"]).first
 if not lang
  Language.create(:name => "Vietnamese", :major => 0)
 else
  lang.major = 0
  lang.save!
 end

 lang = Language.where(["name = 'Yiddish'"]).first
 if not lang
  Language.create(:name => "Yiddish", :major => 0)
 else
  lang.major = 0
  lang.save!
 end

 lang = Language.where(["name = 'Chinese'"]).first
 if not lang
  Language.create(:name => "Chinese", :major => 1)
 else
  lang.major = 1
  lang.save!
 end

 lang = Language.where(["name = 'Zulu'"]).first
 if not lang
  Language.create(:name => "Zulu", :major => 0)
 else
  lang.major = 0
  lang.save!
 end

end


def self.down
end
end
