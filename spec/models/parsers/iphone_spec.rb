require 'rails_helper'

describe Parsers::Iphone do
  describe '#merge' do
    it 'respond to merge' do
      Parsers::Iphone.respond_to? 'merge'
    end

    it 'merge simple string' do
      contents = '"token"="text";'
      language = Language.find(2)
      string_translations = { ['token', language.id] => 'translated text' }
      languages = [language]

      expect(Parsers::Iphone.merge(contents, string_translations, languages)).to eq(language => ['"token"="translated text";', [1, 1]])
    end

    it 'merge multiple strings' do
      contents = "\"token1\"=\"text1\";\n\"token2\"=\"text2\";"
      language = Language.find(2)
      string_translations = {
        ['token1', language.id] => 'translated text1',
        ['token2', language.id] => 'translated text2'
      }
      languages = [language]

      expect(Parsers::Iphone.merge(contents, string_translations, languages)).to eq(language => ["\"token1\"=\"translated text1\";\n\"token2\"=\"translated text2\";", [2, 2]])
    end

    it 'merge string with no semicolon' do
      contents = '"token"="text"'
      language = Language.find(2)
      string_translations = { ['token', language.id] => 'translated text' }
      languages = [language]

      expect(Parsers::Iphone.merge(contents, string_translations, languages)).to eq(language => ['"token"="translated text"', [1, 1]])
    end

    it 'merge string with escaped double quotes' do
      contents = '"token"="my \"text\"";'
      language = Language.find(2)
      string_translations = { ['token', language.id] => 'translated "text"' }
      languages = [language]

      expect(Parsers::Iphone.merge(contents, string_translations, languages)).to eq(language => ['"token"="translated \"text\"";', [1, 1]])
    end

    it 'keeps white spaces on token' do
      contents = '"  token "="text";'
      language = Language.find(2)
      string_translations = { ['  token ', language.id] => 'translated text' }
      languages = [language]

      expect(Parsers::Iphone.merge(contents, string_translations, languages)).to eq(language => ['"  token "="translated text";', [1, 1]])
    end

    it 'adds white spaces on translations if there was on the original text' do
      contents = '"token"="  text  ";'
      language = Language.find(2)
      string_translations = { ['token', language.id] => 'translated text' }
      languages = [language]

      expect(Parsers::Iphone.merge(contents, string_translations, languages)).to eq(language => ['"token"="  translated text  ";', [1, 1]])
    end
  end

  describe '#parse' do
    it 'responde to parser' do
      Parsers::Iphone.respond_to? 'parse'
    end

    it 'parse simple text' do
      text = '"simple token"="simple text";'
      res = Parsers::Iphone.parse(text)
      expect(res.size).to eq(1)

      expect(res.first[:token]).to eq('simple token')
      expect(res.first[:text]).to eq('simple text')
      expect(res.first[:translation]).to eq('simple text')
      expect(res.first[:comments]).to be nil
    end

    it 'parse two strings' do
      text = "\"token0\"=\"text0\";\n\"token1\"=\"text1\";"
      res = Parsers::Iphone.parse(text)
      expect(res.size).to be(2)

      2.times do |i|
        expect(res[i][:token]).to eq("token#{i}")
        expect(res[i][:text]).to eq("text#{i}")
        expect(res[i][:translation]).to eq("text#{i}")
        expect(res[i][:comments]).to be nil
      end
    end

    it 'parse five strings' do
      text = ''
      5.times { |i| text += "\"token#{i}\"=\"text#{i}\";\n" }

      res = Parsers::Iphone.parse(text)
      expect(res.size).to eq(5)

      5.times do |i|
        expect(res[i][:token]).to eq("token#{i}")
        expect(res[i][:text]).to eq("text#{i}")
        expect(res[i][:translation]).to eq("text#{i}")
        expect(res[i][:comments]).to be nil
      end
    end

    it 'parse single line comment' do
      text = "//comment0\n\"token0\"=\"text0\";"
      res = Parsers::Iphone.parse(text)
      expect(res.size).to eq(1)

      expect(res.first[:token]).to eq('token0')
      expect(res.first[:text]).to eq('text0')
      expect(res.first[:translation]).to eq('text0')
      expect(res.first[:comments]).to eq('comment0')
    end

    it 'parse empty lines between single line commend and string' do
      text = "//comment0\n\n\n\n\n\"token0\"=\"text0\";"
      res = Parsers::Iphone.parse(text)
      expect(res.size).to eq 1

      expect(res.first[:token]).to eq('token0')
      expect(res.first[:text]).to eq('text0')
      expect(res.first[:translation]).to eq('text0')
      expect(res.first[:comments]).to eq('comment0')
    end

    it 'parse single line comment five times' do
      text = ''
      5.times { |i| text += "//comment#{i}\n\"token#{i}\"=\"text#{i}\";\n" }

      res = Parsers::Iphone.parse(text)
      expect(res.size).to be(5)

      5.times do |i|
        expect(res[i][:token]).to eq("token#{i}")
        expect(res[i][:text]).to eq("text#{i}")
        expect(res[i][:translation]).to eq("text#{i}")
        expect(res[i][:comments]).to eq("comment#{i}")
      end
    end

    it 'parse multiline comment' do
      text = "/*comment0*/\n\"token0\"=\"text0\";"
      res = Parsers::Iphone.parse(text)
      expect(res.size).to eq 1

      expect(res.first[:token]).to eq('token0')
      expect(res.first[:text]).to eq('text0')
      expect(res.first[:translation]).to eq('text0')
      expect(res.first[:comments]).to eq('comment0')
    end

    it 'prase empty lines between multiline comments and text' do
      text = "/*comment0*/\n\n\n\n\n\"token0\"=\"text0\";"
      res = Parsers::Iphone.parse(text)
      expect(res.size).to eq 1

      expect(res.first[:token]).to eq('token0')
      expect(res.first[:text]).to eq('text0')
      expect(res.first[:translation]).to eq('text0')
      expect(res.first[:comments]).to eq('comment0')
    end

    it 'parse five multiline comments' do
      text = ''
      5.times { |i| text += "/*comment#{i}*/\n\"token#{i}\"=\"text#{i}\";\n" }

      res = Parsers::Iphone.parse(text)
      expect(res.size).to eq 5

      5.times do |i|
        expect(res[i][:token]).to eq "token#{i}"
        expect(res[i][:text]).to eq "text#{i}"
        expect(res[i][:translation]).to eq "text#{i}"
        expect(res[i][:comments]).to eq "comment#{i}"
      end
    end

    it 'parse real multiline comment' do
      text = "/*multi\n\nline\ncomment*/\n\n\n\n\n\"token0\"=\"text0\";"
      res = Parsers::Iphone.parse(text)
      expect(res.size).to eq 1

      expect(res.first[:token]).to eq('token0')
      expect(res.first[:text]).to eq('text0')
      expect(res.first[:translation]).to eq('text0')
      expect(res.first[:comments]).to eq "multi\n\nline\ncomment"
    end

    it 'parse multiline string' do
      string = "My\nmultiline\nstring"
      text = "\"token\"=\"#{string}\";"

      res = Parsers::Iphone.parse(text)
      expect(res.size).to eq 1

      expect(res.first[:token]).to eq 'token'
      expect(res.first[:text]).to eq string
      expect(res.first[:translation]).to eq string
      expect(res.first[:comments]).to be nil
    end

    it 'parse multiline token' do
      token = "My\nmultiline\ntoken"
      text = "\"#{token}\"=\"string\";"

      res = Parsers::Iphone.parse(text)
      expect(res.size).to eq 1

      expect(res.first[:token]).to eq token
      expect(res.first[:text]).to eq 'string'
      expect(res.first[:translation]).to eq 'string'
      expect(res.first[:comments]).to be nil
    end

    it 'parses with blank spaces ' do
      text = '   "simple token"   =    "simple text"   ;     '
      res = Parsers::Iphone.parse(text)
      expect(res.size).to eq 1

      expect(res.first[:token]).to eq 'simple token'
      expect(res.first[:text]).to eq 'simple text'
      expect(res.first[:translation]).to eq 'simple text'
      expect(res.first[:comments]).to be nil
    end

    it 'parse escaped quotes' do
      text = '"token"="simple \" escaped quotes\"";'
      res = Parsers::Iphone.parse(text)
      expect(res.size).to eq 1

      expect(res.first[:token]).to eq 'token'
      expect(res.first[:text]).to eq 'simple \" escaped quotes\"'
      expect(res.first[:translation]).to eq 'simple \" escaped quotes\"'
      expect(res.first[:comments]).to be nil
    end

    it 'parse multiple escaped quotes' do
      text = '"token0"="simple \" escaped quotes0\"";\n"token1"="simple \" escaped quotes1\"";'
      res = Parsers::Iphone.parse(text)
      expect(res.size).to eq 2

      2.times do |i|
        expect(res[i][:token]).to eq "token#{i}"
        expect(res[i][:text]).to eq "simple \\\" escaped quotes#{i}\\\""
        expect(res[i][:translation]).to eq "simple \\\" escaped quotes#{i}\\\""
        expect(res[i][:comments]).to be nil
      end
    end

    it 'parses multiple comments' do
      text = <<-eos
      /* Comment */
      "label0" = "string0";
      /* other comment2 */
      "label1" = "string1";
      eos
      res = Parsers::Iphone.parse(text)
      expect(res.size).to eq 2

      2.times do |i|
        expect(res[i][:token]).to eq "label#{i}"
        expect(res[i][:text]).to eq "string#{i}"
      end
    end

    it 'parsers multiple comments from the same type' do
      text = <<-eos
      // comment1
      // comment2
      // comment3
      "label0" = "string0";
      eos
      res = Parsers::Iphone.parse(text)
      expect(res.size).to eq 1
      expect(res[0][:comments]).to eq 'comment3'
      expect(res[0][:token]).to eq 'label0'
      expect(res[0][:text]).to eq 'string0'
    end
  end
end
