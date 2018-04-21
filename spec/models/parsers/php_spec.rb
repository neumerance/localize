require 'spec_helper'

describe Parsers::Php do
  describe '#merge' do
    it 'respond to merge' do
      Parsers::Php.respond_to? 'merge'
    end
  end

  describe '#parse' do
    it 'respond to parser' do
      Parsers::Php.respond_to? 'parse'
    end

    it 'parse simple text' do
      text = 'define("SIMPLE_TOKEN", "simple text");'
      res = Parsers::Php.parse(text)
      expect(res.size).to eq 1

      expect(res.first[:token]).to eq '"SIMPLE_TOKEN"'
      expect(res.first[:text]).to eq '"simple text"'
      expect(res.first[:translation]).to eq '"simple text"'
    end

    it 'parse two strings' do
      text = "define(\"token0\", \"text0\");\ndefine(\"token1\", \"text1\");"
      res = Parsers::Php.parse(text)
      expect(res.size).to eq 2

      2.times do |i|
        expect(res[i][:token]).to eq "\"token#{i}\""
        expect(res[i][:text]).to eq "\"text#{i}\""
        expect(res[i][:translation]).to eq "\"text#{i}\""
      end
    end

    it 'parse five strings' do
      text = ''
      5.times { |i| text += "define(\"token#{i}\", \"text#{i}\");\n" }

      res = Parsers::Php.parse(text)
      expect(res.size).to eq 5

      5.times do |i|
        expect(res[i][:token]).to eq "\"token#{i}\""
        expect(res[i][:text]).to eq "\"text#{i}\""
        expect(res[i][:translation]).to eq "\"text#{i}\""
      end
    end

    it 'ignore single line comment' do
      text = '//blablabla'
      res = Parsers::Php.parse(text)
      expect(res.size).to eq 0
    end

    it 'parse empty lines between single line commend and string' do
      text = "//comment0\n\n\n\n\n\"define(\"token0\", \"text0\");"
      res = Parsers::Php.parse(text)
      expect(res.size).to eq 1

      expect(res.first[:token]).to eq '"token0"'
      expect(res.first[:text]).to eq '"text0"'
      expect(res.first[:translation]).to eq '"text0"'
      expect(res.first[:comments]).to eq ''
    end

    it 'parse space between comma' do
      text = 'define("SIMPLE_TOKEN"  ,   "simple text");'
      res = Parsers::Php.parse(text)
      expect(res.size).to eq 1

      expect(res.first[:token]).to eq '"SIMPLE_TOKEN"'
      expect(res.first[:text]).to eq '"simple text"'
      expect(res.first[:translation]).to eq '"simple text"'
    end

    it 'parse space in text' do
      text = 'define("SIMPLE_TOKEN"  ,   " simple text ");'
      res = Parsers::Php.parse(text)
      expect(res.size).to eq 1

      expect(res.first[:token]).to eq '"SIMPLE_TOKEN"'
      expect(res.first[:text]).to eq '" simple text "'
      expect(res.first[:translation]).to eq '" simple text "'
    end

    it 'parse space between quotes' do
      text = 'define( "SIMPLE_TOKEN" , "simple text" );'
      res = Parsers::Php.parse(text)
      expect(res.size).to eq 1

      expect(res.first[:token]).to eq '"SIMPLE_TOKEN"'
      expect(res.first[:text]).to eq '"simple text"'
      expect(res.first[:translation]).to eq '"simple text"'
    end

  end
end
