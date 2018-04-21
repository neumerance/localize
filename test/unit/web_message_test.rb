require File.dirname(__FILE__) + '/../test_helper'

class WebMessageTest < ActiveSupport::TestCase
  fixtures :web_dialogs, :users, :web_messages

  # Replace this with your real tests.
  def test_tokenization
    debug = false
    dialog = web_dialogs(:amir_sales_for_translation)
    txts = [['{{hebrew name||my name}} {{cards}}', '{{my name:1}} {{T:2}} and some story', true],
            ['this is a short message {{-values are important-}} let us see', 'translation for {{T:1}} message', true],
            ["another small message {{\na little bit more \ncomplicated 'very'}}).
    						Is {{*this*}} working?", 'put {{T:1}} here and {{T:2}} there', true],
            ['{{too many}} {{tokens}}', '{{T:1}} missing in the translation', false],
            ['{{too many}} {{tokens}}', '{{T:1}} {{T:2}} {{T:3}} missing in the translation', false],
            ['{{too many}} {{tokens}}', '{{T:1}} {{T:2}} missing in the translation', true],
            ['{{too many}} {{tokens}}', '{{T:1}} {{T:1}} missing in the translation', false],
            ['{{too many}} {{tokens}}', '{{T:4}} {{T:3}} missing in the translation', false]]

    txts.each do |txt|
      message = WebMessage.new(
        visitor_body: txt[0],
        translation_status: TRANSLATION_NEEDED,
        word_count: txt[0].split.length
      )
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

  def test_translation_price_per_word
    # Normal client
    message = web_messages(:standalone_message)
    assert_equal INSTANT_TRANSLATION_COST_PER_WORD, message.price_per_word

    # Top client
    message.owner = users(:top_client)
    assert_equal INSTANT_TRANSLATION_COST_PER_WORD * TOP_CLIENT_DISCOUNT, message.price_per_word
  end

  def test_review_price_per_word
    # Normal client
    message = web_messages(:standalone_message)
    assert_equal INSTANT_TRANSLATION_COST_PER_WORD * 0.5, message.review_price_per_word

    # Top client
    message.owner = users(:top_client)
    assert_equal INSTANT_TRANSLATION_COST_PER_WORD * 0.5 * TOP_CLIENT_DISCOUNT, message.review_price_per_word
  end

  def test_price
    ### No managed work ###
    # Normal client
    message = web_messages(:standalone_message)
    expected_price = INSTANT_TRANSLATION_COST_PER_WORD * message.word_count
    normal_client_price = message.price
    assert_in_delta expected_price, normal_client_price, 0.001

    # Top client
    message.owner = users(:top_client)
    message.save!
    expected_price_for_top = message.word_count * (INSTANT_TRANSLATION_COST_PER_WORD * TOP_CLIENT_DISCOUNT).ceil_money
    top_client_price = message.price
    assert_in_delta expected_price_for_top, top_client_price, 0.001

    ### With managed work ###
    message.managed_work = ManagedWork.new(active: MANAGED_WORK_ACTIVE)
    message.save!

    # Top client
    expected_price_for_top = top_client_price +
                             (message.word_count * (INSTANT_TRANSLATION_COST_PER_WORD * 0.5 * TOP_CLIENT_DISCOUNT)).ceil_money
    assert_in_delta expected_price_for_top, message.price, 0.001

    # Normal client
    message.owner = users(:amir)
    message.save!
    assert_in_delta normal_client_price * 1.5, message.price, 0.00
  end

  def test_price_for
    assert_equal INSTANT_TRANSLATION_COST_PER_WORD, WebMessage.price_per_word_for(users(:amir))
    assert_equal INSTANT_TRANSLATION_COST_PER_WORD * TOP_CLIENT_DISCOUNT, WebMessage.price_per_word_for(users(:top_client))
  end
end
