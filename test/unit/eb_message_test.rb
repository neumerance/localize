require File.dirname(__FILE__) + '/../test_helper'

class WebMessageTest < ActiveSupport::TestCase
  fixtures :web_dialogs, :users, :web_messages

  # Replace this with your real tests.
  def test_tokenization
    debug = false
    dialog = web_dialogs(:amir_sales_for_translation)
    txts = [['{{hebrew name||my name}} {{cards}}', '{{my name:1}} {{T:2}} and some story', true],
            ['this is a short message {{-values are important-}} let us see', 'translation for {{T:1}} message', true],
            ["another small message {{\na little bit more \ncomplicated 'very'}}). Is {{*this*}} working?", 'put {{T:1}} here and {{T:2}} there', true],
            ['{{too many}} {{tokens}}', '{{T:1}} missing in the translation', false],
            ['{{too many}} {{tokens}}', '{{T:1}} {{T:2}} {{T:3}} missing in the translation', false],
            ['{{too many}} {{tokens}}', '{{T:1}} {{T:2}} missing in the translation', true],
            ['{{too many}} {{tokens}}', '{{T:1}} {{T:1}} missing in the translation', false],
            ['{{too many}} {{tokens}}', '{{T:4}} {{T:3}} missing in the translation', false]]

    txts.each do |txt|
      message = WebMessage.new(visitor_body: txt[0], translation_status: TRANSLATION_NEEDED, word_count: txt[0].split.length)
      message.owner = dialog
      puts "orig message: #{txt[0]}" if debug
      for_translation = WebMessage.tokenize(message.visitor_body)
      puts "for_translation: #{for_translation}" if debug
      translation = txt[1]
      puts "got back: #{txt[1]}" if debug
      for_update, problems = message.update_token_data(translation, txt[0])
      if debug
        puts "for_update: #{for_update}"
        puts "--> length: #{for_update.length}" if for_update
        puts "\n"
      end
      if txt[2]
        assert !for_update.blank?
        assert !for_update.empty?
        txt[0].gsub(/\{\{[^{}]*\}\}/) do |p|
          val = WebMessage.token_txt(p[2..-3])
          assert for_update[val]
        end
        assert_nil for_update['{{T:']
      else
        assert_nil for_update
      end
    end
  end

  def xtoken_txt(token)
    idx = (/\|/ =~ token)
    if !idx.nil? && (idx > 0)
      return token[2...idx]
    else
      return token[2..-3]
    end
  end

  def test_complex?
    message = web_messages(:message_for_amir_sales)
    assert !message.complex?

    message = web_messages(:message_for_amir_sales_one_user_flag)
    assert !message.complex?

    message = web_messages(:message_for_amir_sales_complex)
    assert message.complex?
  end
end
