require 'rails_helper'

describe Language do
  include ActionDispatch::TestProcess
  fixtures :languages

  @languages = {
    en: 'English',
    es: 'Spanish',
    de: 'German',
    fr: 'French',
    ar: 'Arabic',
    pt: 'Portuguese',
    it: 'Italian',
    'zh-Hans' => 'Chinese (Simplified)',
    'zh-Hant' => 'Chinese (Traditional)'
  }

  @languages.each do |iso, name|
    it "should find language by #{iso} and by #{name}" do
      lang_by_iso = Language.detect_language(iso)
      lang_by_name = Language.detect_language(name)
      expect(lang_by_iso).to be_a(Language)
      expect(lang_by_name).to be_a(Language)
      expect(lang_by_iso).to eq(lang_by_name)
    end
  end

end
