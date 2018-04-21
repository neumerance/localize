require "#{File.dirname(__FILE__)}/../test_helper"

class TimeEventsTest < ActionDispatch::IntegrationTest
  fixtures :users, :money_accounts, :languages, :currencies, :identity_verifications,
           :translator_languages, :categories, :translator_categories, :client_departments,
           :web_supports, :websites, :website_translation_offers, :website_translation_contracts

  def test_project_needs_alert

    # log in as a client
    client = users(:amir)
    project = setup_full_project(client, 'not responded on time')
    revision = project.revisions[0]

    session = login(client)

    # release this revision
    xml_http_request(:post, url_for(controller: :revisions, action: :edit_release_status, project_id: project.id, id: revision.id),
                     session: session, req: 'show')
    assert_response :success
    assert_nil assigns(:warnings)

    # log in as a translator
    translator = users(:orit)
    xsession = login(translator)

    chat_id = create_chat(xsession, project.id, revision.id)
    chat = Chat.find(chat_id)

    # bid on all languages
    bids = []
    amount = MINIMUM_BID_AMOUNT
    [languages(:Spanish), languages(:French), languages(:German)].each do |language|
      bids << translator_bid(xsession, chat, language, amount)
    end

    # log in as a supporter, in order to run administrative tasks
    admin = users(:admin)
    ssession = login(admin)

    # check that once bidding is closed, the client gets a reminder and the alert_status updates
    assert_equal 0, revision.alert_status

    orig_reminders = Reminder.count
    get(url_for(controller: :supporter, action: :bidding_closing),
        session: ssession, t_offset: DAY_IN_SECONDS * (DAYS_TO_BID + 1))
    assert_response :redirect
    assert_equal orig_reminders + 1, Reminder.count

    revision.reload
    assert_equal REVISION_BIDDING_CLOSED_ALERT, revision.alert_status
    assert_equal EVENT_BIDDING_ON_REVISION_CLOSED, revision.reminders[-1].event

    # accept the bids
    client_accepts_bids(session, bids, BID_ACCEPTED)

    check_project_completion(ssession, bids)

  end

  def test_project_doesnt_need_alert

    # log in as a client
    client = users(:amir)
    project = setup_full_project(client, 'not responded on time')
    revision = project.revisions[0]

    session = login(client)

    # release this revision
    xml_http_request(:post, url_for(controller: :revisions, action: :edit_release_status, project_id: project.id, id: revision.id),
                     session: session, req: 'show')
    assert_response :success
    assert_nil assigns(:warnings)

    # log in as a translator
    translator = users(:orit)
    xsession = login(translator)

    chat_id = create_chat(xsession, project.id, revision.id)
    chat = Chat.find(chat_id)

    # bid on all languages
    bids = []
    amount = MINIMUM_BID_AMOUNT
    [languages(:Spanish), languages(:French), languages(:German)].each do |language|
      bids << translator_bid(xsession, chat, language, amount)
    end

    # accept the bids
    client_accepts_bids(session, bids, BID_ACCEPTED)

    # log in as an admin, in order to run administrative tasks
    admin = users(:admin)
    ssession = login(admin)

    # check that once bidding is closed, the client gets a reminder and the alert_status updates
    assert_equal 0, revision.alert_status

    orig_reminders = Reminder.count
    get(url_for(controller: :supporter, action: :bidding_closing),
        session: ssession, t_offset: DAY_IN_SECONDS * (DAYS_TO_BID + 1))
    assert_response :redirect
    assert_equal orig_reminders, Reminder.count

    check_project_completion(ssession, bids)

  end

  def check_project_completion(ssession, all_bids)

    # manually create an arbitration for one bid - it should be skipped by the reminders
    bid = all_bids[0]
    arbitration = Arbitration.new(type_code: MUTUAL_ARBITRATION_CANCEL_BID,
                                  object_id: bid.id,
                                  object_type: 'Bid',
                                  initiator_id: bid.chat.translator_id,
                                  against_id: bid.chat.revision.project.client_id,
                                  status: ARBITRATION_CREATED)
    arbitration.save!

    bids = all_bids[1..-1]

    bids.each do |b|
      b.reload
      assert_equal 0, b.alert_status
    end

    # check that when work needs to complete, both client and translator get a reminder
    orig_reminders = Reminder.count
    get(url_for(controller: :supporter, action: :work_completing),
        session: ssession, t_offset: DAY_IN_SECONDS * (DAYS_TO_COMPLETE_WORK + 1))
    assert_response :redirect
    assert_equal orig_reminders + 2 * bids.length, Reminder.count
    Reminder.all.order('reminders.id DESC').limit(2 * bids.length).each do |reminder|
      assert_equal EVENT_WORK_NEEDS_TO_COMPLETE, reminder.event
    end
    bids.each do |b|
      b.reload
      assert_equal BID_NEEDS_TO_COMPLETE, b.alert_status
    end

    # check that both client and translator get another reminder after a week
    orig_reminders = Reminder.count
    get(url_for(controller: :supporter, action: :work_completing),
        session: ssession, t_offset: DAY_IN_SECONDS * (DAYS_TO_COMPLETE_WORK + DAYS_TO_SEND_WORK_COMPLETION_ALERT + 1))
    assert_response :redirect
    assert_equal orig_reminders + 2 * bids.length, Reminder.count
    Reminder.all.order('reminders.id DESC').limit(2 * bids.length).each do |reminder|
      assert_equal EVENT_BID_ABOUT_TO_GO_TO_ARBITRATION, reminder.event
    end
    bids.each do |b|
      b.reload
      assert_equal BID_ABOUT_TO_GO_TO_ARBITRATION, b.alert_status
    end

    bids.each { |b| assert_nil b.arbitration }

    # check that the bid went into arbitration eventually
    orig_reminders = Reminder.count
    get(url_for(controller: :supporter, action: :work_completing),
        session: ssession, t_offset: DAY_IN_SECONDS * (DAYS_TO_COMPLETE_WORK + DAYS_TO_PUT_BID_IN_ARBITRATION + 1))
    assert_response :redirect
    assert_equal orig_reminders + 2 * bids.length, Reminder.count
    Reminder.all.order('reminders.id DESC').limit(2 * bids.length).each do |reminder|
      assert_equal EVENT_BID_WENT_TO_ARBITRATION, reminder.event
    end
    bids.each do |b|
      b.reload
      assert_equal BID_WENT_TO_ARBITRATION, b.alert_status
      assert b.arbitration
      assert_equal SUPPORTER_ARBITRATION_WORK_MUST_COMPLETE, b.arbitration.type_code
    end

  end

  def test_new_project_for_translators
    client = users(:amir)
    english = languages(:English)
    spanish = languages(:Spanish)
    french = languages(:French)
    italian = languages(:Italian)
    arab = languages(:Arab)
    usd = currencies(:USD)

    orit = users(:orit)
    guy = users(:guy)

    Project.delete_all
    Revision.delete_all

    p1 = Project.create(name: 'proj1', client_id: client.id)
    p2 = Project.create(name: 'proj2', client_id: client.id)
    r1 = Revision.create(
      name: 'initial',
      project_id: p1.id,
      description: "something completely different\nin two lines.",
      released: 1,
      language_id: english.id,
      max_bid: 0.31,
      max_bid_currency: usd.id,
      release_date: Time.now - 10,
      bidding_close_time: Time.now + 6 * DAY_IN_SECONDS,
      project_completion_duration: 5,
      word_count: 1,
      notified: 0
    )

    r2 = Revision.create(
      name: 'initial',
      project_id: p2.id,
      description: 'An ugly French website.',
      released: 1,
      language_id: english.id,
      max_bid: 0.11,
      max_bid_currency: usd.id,
      release_date: Time.now - 10,
      bidding_close_time: Time.now + 6 * DAY_IN_SECONDS,
      project_completion_duration: 2,
      word_count: 1,
      notified: 0
    )

    rl1 = RevisionLanguage.create(revision_id: r1.id, language_id: spanish.id)
    rl2 = RevisionLanguage.create(revision_id: r2.id, language_id: arab.id)
    rl3 = RevisionLanguage.create(revision_id: r2.id, language_id: italian.id)

    checker = PeriodicChecker.new(Time.now)

    # first check, all translators appear
    mails_sent, translator_notifications = checker.per_profile_mailer(nil, false, true)

    assert_equal 2, mails_sent

    assert translator_notifications[orit]
    assert translator_notifications[orit]['revisions']
    assert_equal 2, translator_notifications[orit]['revisions'].length

    assert translator_notifications[guy]
    assert translator_notifications[guy]['revisions']
    assert_equal 1, translator_notifications[guy]['revisions'].length

    # second check, no translators (projects scanned already)
    mails_sent = checker.per_profile_mailer(nil)
    assert_equal 0, mails_sent

  end

  def test_ready_translator_accounts
    checker = PeriodicChecker.new(Time.now)
    res = checker.ready_translator_accounts
  end

  def test_release_hold_from_instant_messages
    WebDialog.destroy_all
    WebMessage.destroy_all
    assert_equal 0, WebDialog.count
    assert_equal 0, WebMessage.count

    department = client_departments(:amir_support)
    store = department.web_support
    client = store.client

    web_dialog = WebDialog.create!(client_department_id: department.id,
                                   visitor_language_id: department.language.id + 1,
                                   email: 'me@hello.com',
                                   fname: 'name',
                                   lname: 'family',
                                   visitor_subject: 'a subject',
                                   status: SUPPORT_TICKET_CREATED,
                                   translation_status: TRANSLATION_NEEDED,
                                   create_time: Time.now,
                                   accesskey: 1234,
                                   message: 'placekeeper')

    web_message = WebMessage.new(visitor_body: 'a body for the message',
                                 word_count: 7,
                                 client_body: Faker::Lorem.words(10).join(' '),
                                 create_time: Time.now,
                                 comment: 'something')
    web_message.associate_with_dialog(web_dialog)

    amount = web_message.translator_payment

    money_account = web_message.money_account
    assert money_account
    starting_balance = 100
    money_account.update_attributes(balance: starting_balance)

    # hold this message
    translator = users(:orit)
    xsession = login(translator)

    post(url_for(controller: :web_messages, action: :hold_for_translation, id: web_message.id, format: :xml), session: xsession)
    assert_response :success

    # make sure the translator managed to hold the message
    web_message.reload
    assert_equal TRANSLATION_IN_PROGRESS, web_message.translation_status

    money_account.reload
    assert_same_amount(starting_balance - amount, money_account.balance)
    assert_same_amount(amount, money_account.hold_sum)

    # see that before the maximal time, the message doesn't get auto released
    checker = PeriodicChecker.new(Time.now + web_message.word_count * MAX_TIME_TO_TRANSLATE_WORD - 10)
    res = checker.release_old_instant_messages
    assert_equal 0, res.length

    # after the maximal time, the message gets auto released
    tomorrow = Time.now.tomorrow
    Time.stubs(:now).returns(tomorrow)
    checker = PeriodicChecker.new(Time.now + web_message.word_count * MAX_TIME_TO_TRANSLATE_WORD + 1000)
    res = checker.release_old_instant_messages
    assert_equal 1, res.length
    Time.unstub :name

    web_message.reload
    assert_equal TRANSLATION_NEEDED, web_message.translation_status

    money_account.reload
    assert_same_amount(starting_balance, money_account.balance)
    assert_same_amount(0, money_account.hold_sum)
  end

  def test_project_with_no_communication
    init_email_deliveries

    client = users(:amir)
    democlient = users(:democlient)

    translator = users(:orit)
    english = languages(:English)
    spanish = languages(:Spanish)

    root = Root.first
    unless root
      root = Root.create!(email: 'root@icanlocalize.com', password: Faker::Internet.password, fname: Faker::Name.first_name, lname: Faker::Name.last_name, nickname: Faker::Name.first_name)
    end

    project = Project.create!(name: 'stale', creation_time: Time.now, kind: MANUAL_PROJECT, client_id: client.id)
    revision = Revision.create!(project_id: project.id, name: 'first', description: 'something', language_id: english.id, released: 1, kind: project.kind)
    revision_language = RevisionLanguage.create!(revision_id: revision.id, language_id: spanish.id)
    chat = Chat.create!(revision_id: revision.id, translator_id: translator.id)

    curtime = Time.now

    # ---- project just started
    start_time = curtime - 1.day
    end_time = curtime + 1.day

    bid = Bid.create!(chat_id: chat.id, revision_language_id: revision_language.id, status: BID_ACCEPTED, amount: 0.1, currency_id: DEFAULT_CURRENCY_ID, accept_time: start_time, expiration_time: end_time)

    checker = PeriodicChecker.new(curtime)
    res = checker.check_for_projects_with_no_progress
    assert_equal 0, res
    check_emails_delivered(0)

    # ---- bid not yet accepted
    start_time = curtime - 5.days
    end_time = curtime + 5.days

    bid.update_attributes!(status: BID_GIVEN, accept_time: start_time, expiration_time: end_time)
    res = checker.check_for_projects_with_no_progress
    assert_equal 0, res
    check_emails_delivered(0)

    # ---- bid has recent translator communication
    bid.update_attributes!(status: BID_ACCEPTED, accept_time: start_time, expiration_time: end_time)

    message = Message.new(body: 'Hi there!', user_id: translator.id, chgtime: Time.now)
    message.owner = chat
    message.save!

    res = checker.check_for_projects_with_no_progress
    assert_equal 0, res
    check_emails_delivered(0)

    # ---- change the project owner to be democlient, practice projects don't need to get alert messages
    project.client = democlient
    project.save!

    message.update_attributes!(chgtime: Time.now - 3.days)
    res = checker.check_for_projects_with_no_progress
    assert_equal 0, res
    check_emails_delivered(0)

    # --- now, the alert should be sent
    project.client = client
    project.save!

    message.update_attributes!(chgtime: Time.now - 3.days)
    res = checker.check_for_projects_with_no_progress
    assert_equal 1, res
    check_emails_delivered(2)

    last_message = Message.order('id DESC').first
    chat = last_message.owner
    assert_equal translator.id, chat.translator_id
    assert_equal client.id, chat.revision.project.client_id

    # warning already sent
    res = checker.check_for_projects_with_no_progress
    assert_equal 0, res
    check_emails_delivered(0)

    # make sure that both client and translator can access the chat
    [client, translator].each do |user|
      session = login(user)
      get(url_for(controller: :chats, action: :show),
          project_id: chat.revision.project_id, revision_id: chat.revision_id, id: chat.id)
      assert_response :success
      logout(session)
    end

  end

  skip def test_session_cleanup
    UserSession.delete_all

    client = users(:amir)
    session = login(client)

    translator = users(:orit)
    session = login(translator)

    assert_equal 2, UserSession.count
    ActiveRecord::SessionStore::Session.count > 0

    checker = PeriodicChecker.new(Time.zone.now + (SESSION_TIMEOUT + 1))
    # NOTE: currently SESSION_TIMEOUT = TAS_TIMEOUT
    checker.clean_old_sessions

    assert_equal 0, UserSession.count
    assert_equal 0, ActiveRecord::SessionStore::Session.count
  end

  def test_available_languages
    AvailableLanguage.delete_all
    checker = PeriodicChecker.new(Time.now)
    checker.rebuild_available_languages

    # puts "\n=== Round 1 ==="
    # als = AvailableLanguage.all
    # als.each do |al|
    # puts "--> From #{al.from_language.name} to #{al.to_language.name} (qualified=#{al.qualified})"
    # end

    assert_equal 13, AvailableLanguage.count

    AvailableLanguage.all.each { |al| al.update_attributes(update_idx: 1) }

    checker.rebuild_available_languages

    # puts "\n=== Round 2 ==="
    # als = AvailableLanguage.all
    # als.each do |al|
    # puts "--> From #{al.from_language.name} to #{al.to_language.name} (qualified=#{al.qualified})"
    # end

    assert_equal 13, AvailableLanguage.count

    Language.all.each do |l|
      # puts "checking #{l.name} - scanned_for_translators=#{l.scanned_for_translators}"
      assert_equal 1, l.scanned_for_translators, "--> checking #{l.name} - scanned_for_translators=#{l.scanned_for_translators}"
    end
    Translator.where('(userstatus IN (?))', [USER_STATUS_QUALIFIED, USER_STATUS_REGISTERED]).each do |t|
      # puts "- checking translator #{t.email} - #{t.scanned_for_languages}"
      assert_equal 1, t.scanned_for_languages
    end
  end

  def test_notify_old_web_messages
    WebMessage.delete_all
    client = users(:amir)
    web_message = WebMessage.new(visitor_language_id: 1, client_language_id: 2, user_id: client.id, translation_status: TRANSLATION_NEEDED,
                                 visitor_body: nil, client_body: 'hello there', create_time: Time.now, word_count: 2, comment: 'something')
    web_message.owner = client
    web_message.save!

    checker = PeriodicChecker.new(Time.now)
    cnt = checker.alert_client_about_instant_messages
    assert_equal 0, cnt

    web_message.update_attributes(create_time: 2.days.ago)
    cnt = checker.alert_client_about_instant_messages
    assert_equal 1, cnt

  end

  def test_close_old_offers
    WebsiteTranslationOffer.all.each { |offer| offer.update_attributes!(status: TRANSLATION_OFFER_CLOSED) }
    WebsiteTranslationOffer.all.limit(4).each { |offer| offer.update_attributes!(status: TRANSLATION_OFFER_OPEN) }

    checker = PeriodicChecker.new(Time.now)
    cnt = checker.close_old_website_offers
    assert_equal 0, cnt

    # now, set some offers as old
    checker.curtime = Time.now + 15.days
    cnt = checker.close_old_website_offers
    assert_equal 4, cnt

    WebsiteTranslationOffer.all.each { |offer| assert_equal TRANSLATION_OFFER_CLOSED, offer.status }

    cnt = checker.close_old_website_offers
    assert_equal 0, cnt

  end

end
