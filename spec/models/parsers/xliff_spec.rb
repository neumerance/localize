require 'rails_helper'

describe Parsers::Xliff do
  let(:xliff_text) do
    <<-XLIFF
      <?xml version="1.0" encoding="UTF-8"?>
      <xliff xmlns="urn:oasis:names:tc:xliff:document:1.2" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" version="1.2" xsi:schemaLocation="urn:oasis:names:tc:xliff:document:1.2 http://docs.oasis-open.org/xliff/v1.2/os/xliff-core-1.2-strict.xsd">
        <file original="en.lproj/Localizable.strings" datatype="plaintext" source-language="en">
          <header>
            <tool tool-id="com.apple.dt.xcode" tool-name="Xcode" tool-version="9.3" build-num="9E145"/>
          </header>
          <body>
            <trans-unit id="To filter by your likes, create an account or login in the Profile screen">
              <source>To filter by your likes, create an account or login in the Profile screen</source>
              <note>No comment provided by engineer.</note>
            </trans-unit>
          </body>
        </file>
      </xliff>
    XLIFF
  end

  describe '#parse' do
    it 'respond to parser' do
      Parsers::Xliff.respond_to? 'parse'
    end

    it 'parses text from xliff' do
      parsed_xliff = Parsers::Xliff.parse xliff_text
      expect(parsed_xliff[0][:comments]).to eq('No comment provided by engineer.')
      expect(parsed_xliff[0][:text]).to eq('To filter by your likes, create an account or login in the Profile screen')
    end
  end

  describe '#merge' do
    it 'respond to merge' do
      Parsers::Xliff.respond_to? 'merge'
    end

    it 'merged strings' do
      contents = xliff_text
      language = Language.find(4)
      language.update(iso: 'fr')
      language.reload
      translated_string = "Pour pouvoir filtrer selon vos \"J'aime\", veuillez créer un compte ou vous connecter à partir de l'écran Profil"
      string_translations = {
        ['en.lproj/Localizable.strings#To filter by your likes, create an account or login in the Profile screen', 4] => translated_string
      }
      languages = [language]
      merged_strings = Parsers::Xliff.merge(contents, string_translations, languages)
      expect(merged_strings.keys).to include(language)
      expect(merged_strings[language][0]).to match("&quot;J'aime&quot;")
      expect(merged_strings[language][1]).to eq([1, 1])
    end
  end
end
