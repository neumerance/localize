class PopulateIsoCodes < ActiveRecord::Migration

def self.up
 lang = Language.where(["name = ?","English"]).first
 if lang
   lang.update_attributes!(:iso=>"en")
 end

 lang = Language.where(["name = ?","Spanish"]).first
 if lang
   lang.update_attributes!(:iso=>"es")
 end

 lang = Language.where(["name = ?","German"]).first
 if lang
   lang.update_attributes!(:iso=>"de")
 end

 lang = Language.where(["name = ?","French"]).first
 if lang
   lang.update_attributes!(:iso=>"fr")
 end

 lang = Language.where(["name = ?","Arabic"]).first
 if lang
   lang.update_attributes!(:iso=>"ar")
 end

 lang = Language.where(["name = ?","Bosnian"]).first
 if lang
   lang.update_attributes!(:iso=>"bs")
 end

 lang = Language.where(["name = ?","Bulgarian"]).first
 if lang
   lang.update_attributes!(:iso=>"bg")
 end

 lang = Language.where(["name = ?","Catalan"]).first
 if lang
   lang.update_attributes!(:iso=>"ca")
 end

 lang = Language.where(["name = ?","Czech"]).first
 if lang
   lang.update_attributes!(:iso=>"cs")
 end

 lang = Language.where(["name = ?","Slavic"]).first
 if lang
   lang.update_attributes!(:iso=>"cu")
 end

 lang = Language.where(["name = ?","Welsh"]).first
 if lang
   lang.update_attributes!(:iso=>"cy")
 end

 lang = Language.where(["name = ?","Danish"]).first
 if lang
   lang.update_attributes!(:iso=>"da")
 end

 lang = Language.where(["name = ?","Greek"]).first
 if lang
   lang.update_attributes!(:iso=>"el")
 end

 lang = Language.where(["name = ?","Esperanto"]).first
 if lang
   lang.update_attributes!(:iso=>"eo")
 end

 lang = Language.where(["name = ?","Estonian"]).first
 if lang
   lang.update_attributes!(:iso=>"et")
 end

 lang = Language.where(["name = ?","Basque"]).first
 if lang
   lang.update_attributes!(:iso=>"eu")
 end

 lang = Language.where(["name = ?","Persian"]).first
 if lang
   lang.update_attributes!(:iso=>"fa")
 end

 lang = Language.where(["name = ?","Finnish"]).first
 if lang
   lang.update_attributes!(:iso=>"fi")
 end

 lang = Language.where(["name = ?","Irish"]).first
 if lang
   lang.update_attributes!(:iso=>"ga")
 end

 lang = Language.where(["name = ?","Hebrew"]).first
 if lang
   lang.update_attributes!(:iso=>"he")
 end

 lang = Language.where(["name = ?","Hindi"]).first
 if lang
   lang.update_attributes!(:iso=>"hi")
 end

 lang = Language.where(["name = ?","Croatian"]).first
 if lang
   lang.update_attributes!(:iso=>"hr")
 end

 lang = Language.where(["name = ?","Hungarian"]).first
 if lang
   lang.update_attributes!(:iso=>"hu")
 end

 lang = Language.where(["name = ?","Armenian"]).first
 if lang
   lang.update_attributes!(:iso=>"hy")
 end

 lang = Language.where(["name = ?","Indonesian"]).first
 if lang
   lang.update_attributes!(:iso=>"id")
 end

 lang = Language.where(["name = ?","Icelandic"]).first
 if lang
   lang.update_attributes!(:iso=>"is")
 end

 lang = Language.where(["name = ?","Italian"]).first
 if lang
   lang.update_attributes!(:iso=>"it")
 end

 lang = Language.where(["name = ?","Japanese"]).first
 if lang
   lang.update_attributes!(:iso=>"ja")
 end

 lang = Language.where(["name = ?","Korean"]).first
 if lang
   lang.update_attributes!(:iso=>"ko")
 end

 lang = Language.where(["name = ?","Kurdish"]).first
 if lang
   lang.update_attributes!(:iso=>"ku")
 end

 lang = Language.where(["name = ?","Latin"]).first
 if lang
   lang.update_attributes!(:iso=>"la")
 end

 lang = Language.where(["name = ?","Latvian"]).first
 if lang
   lang.update_attributes!(:iso=>"lv")
 end

 lang = Language.where(["name = ?","Lithuanian"]).first
 if lang
   lang.update_attributes!(:iso=>"lt")
 end

 lang = Language.where(["name = ?","Macedonian"]).first
 if lang
   lang.update_attributes!(:iso=>"mk")
 end

 lang = Language.where(["name = ?","Maltese"]).first
 if lang
   lang.update_attributes!(:iso=>"mt")
 end

 lang = Language.where(["name = ?","Moldavian"]).first
 if lang
   lang.update_attributes!(:iso=>"mo")
 end

 lang = Language.where(["name = ?","Mongolian"]).first
 if lang
   lang.update_attributes!(:iso=>"mn")
 end

 lang = Language.where(["name = ?","Nepali"]).first
 if lang
   lang.update_attributes!(:iso=>"ne")
 end

 lang = Language.where(["name = ?","Dutch"]).first
 if lang
   lang.update_attributes!(:iso=>"nl")
 end

 lang = Language.where(["name = ?","Norwegian"]).first
 if lang
   lang.update_attributes!(:iso=>"nb")
 end

 lang = Language.where(["name = ?","Panjabi"]).first
 if lang
   lang.update_attributes!(:iso=>"pa")
 end

 lang = Language.where(["name = ?","Polish"]).first
 if lang
   lang.update_attributes!(:iso=>"pl")
 end

 lang = Language.where(["name = ?","Portuguese"]).first
 if lang
   lang.update_attributes!(:iso=>"pt-BR")
 end

 lang = Language.where(["name = ?","Quechua"]).first
 if lang
   lang.update_attributes!(:iso=>"qu")
 end

 lang = Language.where(["name = ?","Romanian"]).first
 if lang
   lang.update_attributes!(:iso=>"ro")
 end

 lang = Language.where(["name = ?","Russian"]).first
 if lang
   lang.update_attributes!(:iso=>"ru")
 end

 lang = Language.where(["name = ?","Slovenian"]).first
 if lang
   lang.update_attributes!(:iso=>"sl")
 end

 lang = Language.where(["name = ?","Somali"]).first
 if lang
   lang.update_attributes!(:iso=>"so")
 end

 lang = Language.where(["name = ?","Albanian"]).first
 if lang
   lang.update_attributes!(:iso=>"sq")
 end

 lang = Language.where(["name = ?","Serbian"]).first
 if lang
   lang.update_attributes!(:iso=>"sr")
 end

 lang = Language.where(["name = ?","Swedish"]).first
 if lang
   lang.update_attributes!(:iso=>"sv")
 end

 lang = Language.where(["name = ?","Tamil"]).first
 if lang
   lang.update_attributes!(:iso=>"ta")
 end

 lang = Language.where(["name = ?","Thai"]).first
 if lang
   lang.update_attributes!(:iso=>"th")
 end

 lang = Language.where(["name = ?","Turkish"]).first
 if lang
   lang.update_attributes!(:iso=>"tr")
 end

 lang = Language.where(["name = ?","Ukrainian"]).first
 if lang
   lang.update_attributes!(:iso=>"uk")
 end

 lang = Language.where(["name = ?","Urdu"]).first
 if lang
   lang.update_attributes!(:iso=>"ur")
 end

 lang = Language.where(["name = ?","Uzbek"]).first
 if lang
   lang.update_attributes!(:iso=>"uz")
 end

 lang = Language.where(["name = ?","Vietnamese"]).first
 if lang
   lang.update_attributes!(:iso=>"vi")
 end

 lang = Language.where(["name = ?","Yiddish"]).first
 if lang
   lang.update_attributes!(:iso=>"yi")
 end

 lang = Language.where(["name = ?","Chinese (Simplified)"]).first
 if lang
   lang.update_attributes!(:iso=>"zh-HK")
 end

 lang = Language.where(["name = ?","Zulu"]).first
 if lang
   lang.update_attributes!(:iso=>"zu")
 end

 lang = Language.where(["name = ?","Chinese (Traditional)"]).first
 if lang
   lang.update_attributes!(:iso=>"zh-CN")
 end

 lang = Language.where(["name = ?","Portugal Portuguese"]).first
 if lang
   lang.update_attributes!(:iso=>"pt-PT")
 end

end


def self.down
end

end
