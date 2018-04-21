require "#{File.dirname(__FILE__)}/../test_helper"
require 'base64'

class WebsiteMessagesTest < ActionDispatch::IntegrationTest
  fixtures :users, :languages, :translator_languages, :websites, :website_translation_offers, :website_translation_contracts

  # TODO: clarify is it needed? spetrunin 11/01/2016
  def dont_test_message_in_wordpress_website

    init_email_deliveries
    root_account = RootAccount.create!(balance: 0, currency_id: DEFAULT_CURRENCY_ID)

    contract = website_translation_offers(:amir_wp_en_es_orit)
    website = offer.website
    client = website.client
    translator = contract.translator
    other_translator = users(:guy)

    money_account = client.find_or_create_account(DEFAULT_CURRENCY_ID)
    money_account.update_attributes(balance: 1000)

    message = run_translate_message(contract, translator, other_translator, root_account, TRANSLATION_COMPLETE)

  end

  def test_message_in_drupal_rpc_website

    init_email_deliveries
    root_account = RootAccount.create!(balance: 0, currency_id: DEFAULT_CURRENCY_ID)

    contract = website_translation_contracts(:amir_drupal_rpc_en_es_orit)
    offer = contract.website_translation_offer
    website = offer.website
    client = website.client
    translator = contract.translator
    other_translator = users(:guy)

    money_account = client.find_or_create_account(DEFAULT_CURRENCY_ID)
    money_account.update_attributes(balance: 1000)

    message = run_translate_message(contract, translator, other_translator, root_account, TRANSLATION_COMPLETE)

  end

  def test_message_in_drupal_poll_website

    init_email_deliveries
    root_account = RootAccount.create!(balance: 0, currency_id: DEFAULT_CURRENCY_ID)

    contract = website_translation_contracts(:amir_drupal_poll_en_es_orit)
    offer = contract.website_translation_offer
    website = offer.website
    client = website.client
    translator = contract.translator
    other_translator = users(:guy)

    money_account = client.find_or_create_account(DEFAULT_CURRENCY_ID)
    money_account.update_attributes(balance: 1000)

    message1 = run_translate_message(contract, translator, other_translator, root_account, TRANSLATION_NOT_DELIVERED)
    message2 = run_translate_message(contract, translator, other_translator, root_account, TRANSLATION_NOT_DELIVERED)
    message3 = run_translate_message(contract, translator, other_translator, root_account, TRANSLATION_NOT_DELIVERED)

    expected_message_ids = [message1.id, message2.id, message3.id]

    get(url_for(controller: :websites, action: :web_messages_for_pickup, id: website.id, accesskey: website.accesskey, format: 'xml'))
    assert_response :success
    xml = get_xml_tree(@response.body)
    # puts xml

    web_messages_for_pickup = xml.root.elements['web_messages_for_pickup']
    assert web_messages_for_pickup
    message_ids = []
    web_messages_for_pickup.elements.each do |e|
      message_id = get_element_attribute(e, 'id').to_i
      assert expected_message_ids.include?(message_id)
      message_ids << message_id
    end
    assert_equal 3, message_ids.length

    # try to clear without supplying the last_id argument
    post(url_for(controller: :websites, action: :ack_message_pickup, id: website.id, format: 'xml'),
         accesskey: website.accesskey)
    assert_response :success
    xml = get_xml_tree(@response.body)
    assert_element_text('1', xml.root.elements['aborted'])

    # clear up to a certain message
    post(url_for(controller: :websites, action: :ack_message_pickup, id: website.id, format: 'xml'),
         accesskey: website.accesskey, last_id: message_ids[-2])
    assert_response :success
    xml = get_xml_tree(@response.body)
    assert_element_attribute(2.to_s, xml.root.elements['acked'], 'count')

    # make sure that the two first messages are cleared
    [message1, message2].each do |message|
      message.reload
      assert_equal TRANSLATION_COMPLETE, message.translation_status
    end

    message3.reload
    assert_equal TRANSLATION_NOT_DELIVERED, message3.translation_status

    # clear up the last one too
    post(url_for(controller: :websites, action: :ack_message_pickup, id: website.id, format: 'xml'),
         accesskey: website.accesskey, last_id: message_ids[-1])
    assert_response :success
    xml = get_xml_tree(@response.body)
    assert_element_attribute(1.to_s, xml.root.elements['acked'], 'count')

    message3.reload
    assert_equal TRANSLATION_COMPLETE, message3.translation_status

  end

  def run_translate_message(contract, translator, other_translator, _root_account, expected_translation_status)

    offer = contract.website_translation_offer
    website = offer.website
    client = website.client

    visitor_language = offer.from_language
    client_language = offer.to_language

    body = 'this is the message that needs to be translated'
    signature = Digest::MD5.hexdigest(body + visitor_language.name + client_language.name)
    post(url_for(controller: :websites, action: :create_message, id: website.id, format: 'xml'),
         accesskey: website.accesskey, body: Base64.encode64(body),
         from_language: visitor_language.name, to_language: client_language.name,
         signature: signature)
    assert_response :success

    xml = get_xml_tree(@response.body)

    message_id = get_element_attribute(xml.root.elements['result'], 'id').to_i
    message = WebMessage.find(message_id)
    assert message
    assert_equal body, message.visitor_body
    assert_nil message.client_body
    assert_nil message.user
    assert_equal TRANSLATION_NEEDED, message.translation_status
    assert_equal body.split.length, message.word_count
    assert_equal visitor_language.id, message.visitor_language_id
    assert_equal client_language.id, message.client_language_id
    assert_equal website, message.owner

    assert_same_amount(message.word_count * contract.amount, message.client_cost)

    money_account = client.find_or_create_account(DEFAULT_CURRENCY_ID)
    assert_equal money_account, message.money_account

    session = login(client)

    # check the message status
    get(url_for(controller: :web_messages, action: :show, id: message.id, format: :xml))
    assert_response :success
    xml = get_xml_tree(@response.body)
    assert_element_text(nil, xml.root.elements['message'])
    assert_element_attribute(TRANSLATION_NEEDED.to_s, xml.root.elements['message'], 'translation_status')

    logout(session)

    prev_client_balance = money_account.balance

    # see that before the transaction the translator doesn't have any money
    translator_account = translator.get_money_account(DEFAULT_CURRENCY_ID)
    prev_translator_balanace = translator_account.balance

    # --- log in as another translator, who doesn't have a contract for this website
    session = login(other_translator)

    open_messages = other_translator.open_web_messages
    assert_equal 0, open_messages.length

    get(url_for(controller: :web_messages, action: :fetch_next, format: :xml))
    assert_response :success

    xml = get_xml_tree(@response.body)
    err_code = get_element_attribute(xml.root.elements['status'], 'err_code').to_i
    assert_equal NO_MESSAGES_TO_TRANSLATE, err_code

    logout(session)

    # --- check with a translator who does have a contract
    session = login(translator)

    open_messages = translator.open_web_messages
    assert_equal 1, open_messages.length

    get(url_for(controller: :web_messages, action: :fetch_next, format: :xml))
    assert_response :success

    xml = get_xml_tree(@response.body)
    err_code = get_element_attribute(xml.root.elements['status'], 'err_code').to_i
    assert_equal MESSAGE_HELD_FOR_TRANSLATION, err_code

    # assert_element_attribute(String(MESSAGE_HELD_FOR_TRANSLATION), xml.root.elements['status'], 'err_code')
    message_id = get_element_attribute(xml.root.elements['message'], 'id').to_i
    assert_equal message_id, message.id

    translation_body = 'this is the translation.'

    put("/web_messages/#{message.id}",
        body: Base64.encode64(translation_body), body_md5: Digest::MD5.hexdigest(Base64.encode64(translation_body)))
    assert_response :redirect

    message.reload
    assert_equal translation_body, message.client_body
    assert_equal expected_translation_status, message.translation_status

    # check another update by the same translator (in case the translator didn't see the completion message)
    put("/web_messages/#{message.id}",
        body: Base64.encode64(translation_body), body_md5: Digest::MD5.hexdigest(Base64.encode64(translation_body)))
    assert_response :redirect

    logout(session)

    # check that the right payment was made
    translator_account.reload
    assert_same_amount(prev_translator_balanace + message.translator_payment * (1 - FEE_RATE), translator_account.balance)

    money_account.reload
    assert_same_amount(prev_client_balance - message.translator_payment, money_account.balance)

    # --- pick up the translation
    session = login(client)

    get(url_for(controller: :web_messages, action: :show, id: message.id, format: :xml))
    assert_response :success
    xml = get_xml_tree(@response.body)
    assert_element_text(translation_body, xml.root.elements['message'])
    assert_element_attribute(expected_translation_status.to_s, xml.root.elements['message'], 'translation_status')

    logout(session)

    message

  end
end
