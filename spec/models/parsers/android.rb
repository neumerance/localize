require File.dirname(__FILE__) + '/../../test_helper'

class AndroidTest < ActiveSupport::TestCase
  context 'Implements interface' do
    is_expected.to 'respond to merge' do
      Parsers::Android.respond_to? 'merge'
    end

    is_expected.to 'responde to parser' do
      Parsers::Android.respond_to? 'merge'
    end
  end

  context 'Test parser' do
    test 'simple parsing' do
      text = '<resources><string name="token">text</string></resources>'
      res = Parsers::Android.parse(text)
      assert_equal 1, res.size

      assert_equal 'token', res.first[:token]
      assert_equal 'text', res.first[:text]
      assert_equal 'text', res.first[:translation]
      assert_nil res.first[:comments]
    end

    test 'two strings' do
      text = '
      <resources>
        <string name="token0">text0</string>
        <string name="token1">text1</string>
      </resources>'
      res = Parsers::Android.parse(text)
      assert_equal 2, res.size

      2.times do |i|
        assert_equal "token#{i}", res[i][:token]
        assert_equal "text#{i}", res[i][:text]
        assert_equal "text#{i}", res[i][:translation]
        assert_nil res[i][:comments]
      end
    end

    test 'five strings' do
      text = "
      <resources>
        #{Array.new(5) { |i| "<string name=\"token#{i}\">text#{i}</string>" }.join}
      </resources>"

      res = Parsers::Android.parse(text)
      assert_equal 5, res.size

      5.times do |i|
        assert_equal "token#{i}", res[i][:token]
        assert_equal "text#{i}", res[i][:text]
        assert_equal "text#{i}", res[i][:translation]
        assert_nil res[i][:comments]
      end
    end

    test 'random new lines' do
      text = "<resources>\n\n\n<string name=\"token\">\n\ntext\n\n\n</string>\n\n\n\n</resources>"
      res = Parsers::Android.parse(text)
      assert_equal 1, res.size

      assert_equal 'token', res.first[:token]
      assert_equal 'text', res.first[:text]
      assert_equal 'text', res.first[:translation]
      assert_nil res.first[:comments]
    end

    test 'with comments' do
      text = '<resources><!--This comment will be ignored--><string name="token">text</string></resources>'
      res = Parsers::Android.parse(text)
      assert_equal 1, res.size

      assert_equal 'token', res.first[:token]
      assert_equal 'text', res.first[:text]
      assert_equal 'text', res.first[:translation]
      assert_nil res.first[:comments]
    end

    test 'new lines in text' do
      text = "<resources><!--This comment will be ignored--><string name=\"token\">t\ne\nx\nt</string></resources>"
      res = Parsers::Android.parse(text)
      assert_equal 1, res.size

      assert_equal 'token', res.first[:token]
      assert_equal "t\ne\nx\nt", res.first[:text]
      assert_equal "t\ne\nx\nt", res.first[:translation]
      assert_nil res.first[:comments]
    end

    test 'new lines in token' do
      text = "<resources><!--This comment will be ignored--><string name=\"t\no\nk\ne\nn\">text</string></resources>"
      res = Parsers::Android.parse(text)
      assert_equal 1, res.size

      assert_equal "t\no\nk\ne\nn", res.first[:token]
      assert_equal 'text', res.first[:text]
      assert_equal 'text', res.first[:translation]
      assert_nil res.first[:comments]
    end

    test 'escaped quote on token' do
      text = '<resources><string name="t\"oken">text</string></resources>'
      res = Parsers::Android.parse(text)
      assert_equal 1, res.size

      assert_equal 'token', res.first[:token]
      assert_equal 'text', res.first[:text]
      assert_equal 'text', res.first[:translation]
      assert_nil res.first[:comments]
    end
  end

  context 'merge' do
    # TODO: Test merge of iphone file
  end
end
