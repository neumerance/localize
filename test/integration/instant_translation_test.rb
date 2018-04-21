require "#{File.dirname(__FILE__)}/../test_helper"

class InstantTranslationTest < ActionDispatch::IntegrationTest
  fixtures :users, :translator_languages, :money_accounts, :languages, :currencies, :projects, :revisions, :chats, :identity_verifications

  def test_user_create_project

    generate_available_languages

    client = users(:amir)
    session = login(client)

    name = 'hello project'
    client_body = 'this is my message to translate. It is {{important to me}}.'
    comment = 'Do this and that'
    client_language_id, to_language_ids = create_message(name, client_body, comment)

    before_messages = client.web_messages.count

    # create the projects
    post(url_for(controller: :web_messages, action: :create))
    assert_response :success
    client.reload
    assert_equal before_messages + 2, client.web_messages.count

    message = client.web_messages[-1]
    assert_equal message.name, name
    assert_equal message.get_name, name
    assert_equal message.client_body, client_body
    assert_equal message.client_language_id, client_language_id
    assert to_language_ids.include?(message.visitor_language_id)
    assert_equal message.translation_status, TRANSLATION_NEEDED
    assert_nil message.translator_id

    get(url_for(controller: :web_messages, action: :index))
    assert_response :success

    current_logout
  end

  def test_visitor_create_project

    generate_available_languages

    init_email_deliveries

    name = 'hello project'
    client_body = 'this is my message to translate. It is {{important to me}}.'
    comment = 'Do this and that'
    client_language_id, to_language_ids = create_message(name, client_body, comment)

    before_users = TemporaryUser.count
    before_messages = WebMessage.count
    before_invoices = Invoice.count
    # create the projects
    post(url_for(controller: :web_messages, action: :create))
    assert_response :redirect

    assert_equal before_users + 1, TemporaryUser.count
    assert_equal before_messages + 2, WebMessage.count
    temp_user = TemporaryUser.all.to_a[-1]
    assert_equal 'TemporaryUser', temp_user[:type]
    assert_equal 2, temp_user.web_messages.length
    assert_equal before_invoices + 1, Invoice.count
    invoice = Invoice.all.to_a[-1]
    assert_equal TRANSFER_PENDING, invoice.status
    assert_nil invoice.txn

    visitor_email = 'visitor@test.com'
    visitor_fname = 'george'
    visitor_lname = 'gray'
    txn = 'PP1234'

    # before payment, there's no money account for the messages
    temp_user.web_messages.each do |m|
      assert !m.has_enough_money_for_translation?
    end

    assert_nil User.where('email=?', visitor_email).first

    amount = pay_for_messages(temp_user.web_messages, invoice, visitor_email, visitor_fname, visitor_lname, txn, 1)

    user = Client.where('email=?', visitor_email).first
    assert user
    user.reload
    assert_equal 2, user.web_messages.length

    assert_equal 1, user.money_accounts.length
    account = user.money_accounts[0]
    assert_same_amount(amount, account.balance)

    assert_equal 1, user.external_accounts.length
    external_account = user.external_accounts[0]
    assert_equal visitor_email, external_account.identifier

    # make sure that the temporary user has been deleted
    assert_nil User.where('id=?', temp_user.id).first

    # after payment, there's no money account for the messages
    user.web_messages.each do |m|
      assert m.money_account
      assert m.has_enough_money_for_translation?
    end

    UserSession.delete_all

    # Now, do another message, see that it's appended to the correct user
    name = 'hello project2'
    client_body2 = 'this is my message to translate. It is {{important to me}}. again'
    comment = 'Do this and that2'
    client_language_id, to_language_ids = create_message(name, client_body2, comment)

    # create the projects
    post(url_for(controller: :web_messages, action: :create))
    assert_response :redirect

    # make sure that a temporary user wasn't created
    assert_equal before_users + 1, TemporaryUser.count
    temp_user = TemporaryUser.all.to_a[-1]

    assert_equal before_invoices + 2, Invoice.count
    invoice = Invoice.all.to_a[-1]
    assert_equal TRANSFER_PENDING, invoice.status
    assert_nil invoice.txn

    txn = 'PP1235'
    amount2 = pay_for_messages(temp_user.web_messages, invoice, visitor_email, visitor_fname, visitor_lname, txn, 1)

    assert amount2 > amount

    user.reload
    assert_equal 4, user.web_messages.length

    account.reload
    assert_same_amount(amount + amount2, account.balance)

    # check that all transactions appear legal to the admin too
    admin = users(:admin)
    session = login(admin)

    get(url_for(controller: :admin_finance, action: :external_transactions))
    assert_response :success

    logout(session)
  end

  def test_payment_needed
    CmsRequest.delete_all

    generate_available_languages

    init_email_deliveries

    user = users(:amir)
    session = login(user)

    user.web_messages.delete_all
    # user.websites.delete_all

    user.reload

    account = user.find_or_create_account(DEFAULT_CURRENCY_ID)
    account.update_attributes(balance: 0)

    # get rid of any other pending payments
    user.money_accounts.each do |act|
      WebMessage.joins(:money_account).
        where("(money_accounts.id = ?)
					AND (web_messages.translation_status = ?)", act.id, TRANSLATION_NEEDED).each(&:destroy)
    end

    name = 'hello project'
    client_body = 'this is my message to translate. It is {{important to me}}.'
    comment = 'Do this and that'
    client_language_id, to_language_ids = create_message(name, client_body, comment)

    before_messages = WebMessage.count
    before_invoices = Invoice.count
    # create the projects
    post(url_for(controller: :web_messages, action: :create))
    assert_redirected_to controller: :web_supports, action: :untranslated_messages
    follow_redirect!

    # there's not enough money to do this job
    required_deposit = assigns(:required_deposit)
    assert_equal 1.98, required_deposit

    # TODO: Add more tests to check finance page

    user.reload
    assert_equal 2, user.web_messages.length

    checker = PeriodicChecker.new(Time.now)
    # Disabled by icldev-2690.
    # cnt = checker.alert_client_about_low_funding
    # assert_equal 1, cnt
    # check_emails_delivered(1)

    # make sure that all messages require funding
    t = Time.now - (30 * 60 + 1)
    user.web_messages.each do |m|
      m.reload
      assert_equal TRANSLATION_NEEDED, m.translation_status
      assert !m.has_enough_money_for_translation?
      m.update_attributes(create_time: t)
      m.reload
    end

    # this alert is sent just once
    # Disabled by icldev-2690.
    # cnt = checker.alert_client_about_low_funding
    # assert_equal 0, cnt
    # check_emails_delivered(0)

    # make sure that all messages require funding
    t = Time.now - (65 * 60 + 1)
    user.web_messages.each do |m|
      m.update_attributes(create_time: t)
      m.reload
    end

    get(url_for(controller: :web_supports, action: :untranslated_messages))
    assert_response :success

    assert assigns(:required_deposit) > 0

    to_account = assigns(:account)
    assert_equal account, to_account

    total_payment = 0
    user.web_messages.each { |m| total_payment += m.client_cost }

    amount = assigns(:required_deposit)
    assert amount >= total_payment

    assert_equal before_invoices, Invoice.count

    post(url_for(controller: :finance, action: :make_deposit, req: :save, id: account.id),
         params: { amount: amount })
    assert_response :redirect

    assert_equal before_invoices + 1, Invoice.count

    invoice = Invoice.all.to_a[-1]

    txn = 'PP1235'
    amount2 = pay_for_messages(user.web_messages, invoice, user.email, user.fname, user.lname, txn, 0, amount)

    user.web_messages.each do |m|
      m.reload
      assert_equal TRANSLATION_NEEDED, m.translation_status
      assert t < m.create_time, "Create time didn't update: old=#{t}, current: #{m.create_time}"
    end

    # Disabled by icldev-2690.
    # cnt = checker.alert_client_about_low_funding
    # assert_equal 0, cnt

    # make sure that translators would get a notification about these projects that still need to be done
    user.web_messages.each do |m|
      m.update_attributes(create_time: Time.at(0))
    end

    # before 4 hours pass, no alert
    checker.curtime = Time.at(0) + 2.hours
    cnt = checker.remind_about_instant_messages
    assert_equal 0, cnt

    # after 4 hours, alerts should be sent
    checker.curtime = Time.at(0) + 5.hours

    cnt = checker.remind_about_instant_messages
    assert cnt > 0

  end

  def test_translation_only

    init_email_deliveries

    generate_available_languages

    client = users(:amir)
    session = login(client)

    name = 'hello project'
    client_body = 'this is my message to translate..'
    comment = 'Do this and that'
    client_language_id, to_language_ids = create_message(name, client_body, comment, false)

    before_messages = client.web_messages.count

    # create the projects
    post(url_for(controller: :web_messages, action: :create))
    assert_response :success
    client.reload
    assert_equal before_messages + 2, client.web_messages.count

    client.web_messages[-2..-1].each do |message|
      # check that it's being reviewed
      assert_nil message.managed_work

      # check the message itself
      assert_equal message.name, name
      assert_equal message.get_name, name
      assert_equal message.client_body, client_body
      assert_equal message.client_language_id, client_language_id
      assert to_language_ids.include?(message.visitor_language_id)
      assert_equal message.translation_status, TRANSLATION_NEEDED
      assert_nil message.translator_id
    end

    get(url_for(controller: :web_messages, action: :index))
    assert_response :success

    current_logout

    # log in as the translator
    translator = users(:orit)
    session = login(translator)

    get(url_for(controller: :web_messages, action: :index, format: 'xml'))
    assert_response :success

    assert assigns(:messages)
    messages = assigns(:messages)
    assert_equal 2, messages.length

    translated_messages = []

    messages.each do |_m|

      get(url_for(controller: :web_messages, action: :fetch_next, format: :xml))
      assert_response :success

      xml = get_xml_tree(@response.body)

      err_code = get_element_attribute(xml.root.elements['status'], 'err_code').to_i
      assert_equal MESSAGE_HELD_FOR_TRANSLATION, err_code

      assert_element_attribute(client.id.to_s, xml.root.elements['message'], 'client_id')

      message_id = get_element_attribute(xml.root.elements['message'], 'id').to_i
      assert message_id > 0
      message = WebMessage.find(message_id)

      message.reload
      message.money_account.reload
      assert_same_amount(message.translator_payment, message.money_account.hold_sum)

      translated_messages << message

      # --- do the translation ---

      translation_body = 'this is the great translation.'
      translation_title = 'this is the title'

      body_md5 = Digest::MD5.hexdigest(Base64.encode64(translation_body))
      title_md5 = Digest::MD5.hexdigest(Base64.encode64(translation_title))

      put(url_for(controller: :web_messages, action: :update, id: message.id, format: :xml),
          params: {
            body: Base64.encode64(translation_body), title: Base64.encode64(translation_title),
            body_md5: body_md5, title_md5: title_md5, ignore_warnings: 1
          })
      assert_response :success

      xml = get_xml_tree(@response.body)

      assert_element_attribute(String(TRANSLATION_COMPLETED_OK), xml.root.elements['status'], 'err_code')
      message.reload
      assert_equal translation_body, message.visitor_body
      assert_equal TRANSLATION_COMPLETE, message.translation_status
      assert_equal translator, message.translator
      check_emails_delivered(1)

      message.reload
      message.money_account.reload
      assert_same_amount(0, message.money_account.hold_sum)
    end

    # check that the translator doesn't see the messages for review
    get(url_for(controller: :web_messages, action: :review_index))
    assert_response :success

    assert assigns(:messages)
    assert_equal 0, assigns(:messages).length

    logout(session)
  end

  def test_translation_and_review

    init_email_deliveries

    generate_available_languages

    client = users(:amir)
    session = login(client)

    name = 'hello project'
    client_body = 'this is my message to translate..'
    comment = 'Do this and that'
    client_language_id, to_language_ids = create_message(name, client_body, comment, true)

    before_messages = client.web_messages.count

    # create the projects
    post(url_for(controller: :web_messages, action: :create))
    assert_response :success
    client.reload
    assert_equal before_messages + 2, client.web_messages.count

    client.web_messages[-2..-1].each do |message|
      # check that it's being reviewed
      assert message.managed_work
      assert_nil message.managed_work.translator
      assert_equal MANAGED_WORK_CREATED, message.managed_work.translation_status
      assert_equal MANAGED_WORK_ACTIVE, message.managed_work.active

      # check the message itself
      assert_equal message.name, name
      assert_equal message.get_name, name
      assert_equal message.client_body, client_body
      assert_equal message.client_language_id, client_language_id
      assert to_language_ids.include?(message.visitor_language_id)
      assert_equal message.translation_status, TRANSLATION_NEEDED
      assert_nil message.translator_id
    end

    get(url_for(controller: :web_messages, action: :index))
    assert_response :success

    current_logout

    # log in as the translator
    translator = users(:orit)
    session = login(translator)

    get(url_for(controller: :web_messages, action: :index, format: 'xml'))
    assert_response :success

    assert assigns(:messages)
    messages = assigns(:messages)
    assert_equal 2, messages.length

    translated_messages = []

    messages.each do |_m|

      get(url_for(controller: :web_messages, action: :fetch_next, format: :xml))
      assert_response :success

      xml = get_xml_tree(@response.body)

      err_code = get_element_attribute(xml.root.elements['status'], 'err_code').to_i
      assert_equal MESSAGE_HELD_FOR_TRANSLATION, err_code

      assert_element_attribute(client.id.to_s, xml.root.elements['message'], 'client_id')

      message_id = get_element_attribute(xml.root.elements['message'], 'id').to_i
      assert message_id > 0
      message = WebMessage.find(message_id)

      message.reload
      message.money_account.reload
      assert_same_amount(message.translator_payment, message.money_account.hold_sum)

      translated_messages << message

      # --- do the translation ---

      translation_body = 'this is the great translation.'
      translation_title = 'this is the title'

      body_md5 = Digest::MD5.hexdigest(Base64.encode64(translation_body))
      title_md5 = Digest::MD5.hexdigest(Base64.encode64(translation_title))

      put(url_for(controller: :web_messages, action: :update, id: message.id, format: :xml),
          params: {
            body: Base64.encode64(translation_body), title: Base64.encode64(translation_title),
            body_md5: body_md5, title_md5: title_md5, ignore_warnings: 1, omg: 'YEEEEEY'
          })
      assert_response :success

      xml = get_xml_tree(@response.body)

      assert_element_attribute(String(TRANSLATION_COMPLETED_OK), xml.root.elements['status'], 'err_code')
      message.reload
      assert_equal translation_body, message.visitor_body
      assert_equal TRANSLATION_COMPLETE, message.translation_status
      assert_equal translator, message.translator
      check_emails_delivered(1)

      # still not being reviewed
      assert_equal MANAGED_WORK_CREATED, message.managed_work.translation_status
      assert_nil message.managed_work.translator

      message.reload
      message.money_account.reload
      assert_same_amount(0, message.money_account.hold_sum)

    end

    # check that the translator doesn't see the messages for review
    get(url_for(controller: :web_messages, action: :review_index))
    assert_response :success

    assert assigns(:messages)
    assert_equal 0, assigns(:messages).length

    logout(session)

    # log in as a second translator to review
    reviewer = users(:guy)
    session = login(reviewer)

    get(url_for(controller: :web_messages, action: :review_index))
    assert_response :success

    assert assigns(:messages)
    review_messages = assigns(:messages)
    assert_equal 2, review_messages.length

    money_account = reviewer.find_or_create_account(DEFAULT_CURRENCY_ID)
    root_account = RootAccount.first

    review_messages.each do |_m|

      # try without the 'review' argument, should fail
      get(url_for(controller: :web_messages, action: :fetch_next, format: :xml))
      assert_response :success

      xml = get_xml_tree(@response.body)
      err_code = get_element_attribute(xml.root.elements['status'], 'err_code').to_i
      assert_equal TRANSLATION_ALREADY_COMPLETED, err_code

      # try with the 'review' argument, should pass
      get(url_for(controller: :web_messages, action: :fetch_next, review: 1, format: :xml))
      assert_response :success

      xml = get_xml_tree(@response.body)
      err_code = get_element_attribute(xml.root.elements['status'], 'err_code').to_i
      assert_equal err_code, MESSAGE_HELD_FOR_TRANSLATION

      assert_element_attribute(client.id.to_s, xml.root.elements['message'], 'client_id')

      message_id = get_element_attribute(xml.root.elements['message'], 'id').to_i
      assert message_id > 0
      message = WebMessage.find(message_id)

      message.reload
      message.money_account.reload
      assert_same_amount(message.reviewer_payment, message.money_account.hold_sum)

      assert_equal MANAGED_WORK_REVIEWING, message.managed_work.translation_status
      assert message.managed_work.translator

      money_account.reload
      root_account.reload
      prev_balance = money_account.balance
      prev_root_balance = root_account.balance

      # complete the review
      post(url_for(controller: :web_messages, action: :review_complete, id: message.id))
      assert_response :redirect

      message.reload
      message.money_account.reload

      assert_equal MANAGED_WORK_COMPLETE, message.managed_work.translation_status

      check_emails_delivered(1)

      message.reload
      message.money_account.reload
      assert_same_amount(0, message.money_account.hold_sum)

      payment = message.reviewer_payment

      money_account.reload
      root_account.reload
      assert_same_amount(prev_balance + (payment * (1 - FEE_RATE)), money_account.balance)
      assert_same_amount(prev_root_balance + (payment * FEE_RATE), root_account.balance)

    end

    # check that there are no messages to review
    get(url_for(controller: :web_messages, action: :review_index))
    assert_response :success

    assert assigns(:messages)
    assert_equal 0, assigns(:messages).length

    logout(session)

    session = login(client)
    client.web_messages.each do |web_message|
      get(url_for(controller: :web_messages, action: :show, id: web_message.id))
      assert_response :success
    end

    logout(session)

  end

  # ----------------------------

  def create_message(name, client_body, comment, review = false)
    get(url_for(controller: :web_messages, action: :new))
    assert_response :success
    assert_equal 2, assigns('languages').length

    client_language_id = assigns('languages')[0][1]
    post(url_for(controller: :web_messages, action: :pre_create),
         params: { web_message: { name: name, client_language_id: client_language_id, client_body: client_body, comment: comment } })
    assert_response :success
    assert_equal 5, assigns('to_languages').length

    # choose Spanish and German
    to_language_ids = []
    assigns('to_languages').each do |k, v|
      # puts "#{k}: #{v.join(',')}"
      to_language_ids << v[0] if %w(Spanish German).include?(k)
    end
    assert_equal 2, to_language_ids.length

    # click to select, but don't specify a language
    post url_for(controller: :web_messages, action: :select_to_languages), xhr: true
    assert_response :success
    assert assigns('web_message')
    assert assigns('warning')

    # click to select, with selected languages
    post url_for(controller: :web_messages, action: :select_to_languages),
         xhr: true, params: { 'language' => { to_language_ids[0] => '1', to_language_ids[1] => '1' }, :review => (review ? 1 : 0) }

    assert_response :success
    assert assigns('web_message')
    assert_nil assigns('warning')

    [client_language_id, to_language_ids]
  end

  def pay_for_messages(messages, invoice, visitor_email, visitor_fname, visitor_lname, txn, emails_delivered, payment_amount = nil)
    amount = 0
    if payment_amount
      amount = payment_amount
    else
      messages.each { |m| amount += m.client_cost }
    end
    assert amount > 0

    fee = amount * 0.1

    # now, do the PayPal IPN for this payment
    tx = PaypalMockReply.new(payer_email: visitor_email,
                             first_name: visitor_fname,
                             last_name: visitor_lname)

    tx.save
    tx.update_attributes(txn_id: txn,
                         business: Figaro.env.PAYPAL_BUSINESS_EMAIL,
                         mc_gross: amount,
                         mc_currency: 'USD',
                         mc_fee: fee,
                         payment_status: 'Completed',
                         payer_status: 'verified',
                         invoice: invoice.id,
                         txn_type: 'web_accept')

    post(url_for(controller: :finance, action: :paypal_ipn), params: tx.attributes)
    assert_response :success
    assert_nil assigns['retry']
    assert_nil assigns['errors']

    invoice.reload

    assert_equal invoice.status, TXN_COMPLETED
    assert_equal invoice.txn, txn

    check_emails_delivered(emails_delivered + 1)
    post(url_for(controller: :finance, action: :paypal_complete), params: tx.attributes)
    assert_response :success

    if emails_delivered > 0
      assert assigns['user']
      assert_equal visitor_email, assigns['user'].email
    end
    check_emails_delivered(0)

    amount
  end

  def generate_available_languages
    AvailableLanguage.regenarate
    assert_not_equal 0, AvailableLanguage.count
  end

end
