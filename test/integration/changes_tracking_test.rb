require "#{File.dirname(__FILE__)}/../test_helper"
require 'zlib'

class ChangesTrackingTest < ActionDispatch::IntegrationTest
  fixtures :users, :money_accounts, :languages, :currencies, :translator_languages, :identity_verifications,
           :text_resources, :resource_chats, :resource_strings, :string_translations,
           :resource_stats, :managed_works, :phones, :cats

  def test_client_updates

    # make sure we start clean
    clear_all

    init_email_deliveries

    files_to_delete = []

    # ------------------------------ client project setup ----------------------------

    # log in as a client
    client = users(:amir)
    session = login(client)

    client_account = find_user_account(client, 1)
    assert client_account

    # create a project
    project_id = create_project(session, 'Dummy proj')
    project = Project.find(project_id)

    # add a track to the project
    # post(url_for(:controller=>:changes, :action=>:track_project),
    # {:session=>session, :id=>project_id, :format=>'xml' } )
    # assert_response :success

    changenum = get_track_num(session)

    # create a new revision
    revision_id = create_revision(session, project_id, 'Created by test')
    revision = Revision.find(revision_id)
    changenum = assert_track_changes(session, changenum, "Changenum didn't increment after revision was created")
    assert_nil revision.get_stats

    # ---------------- upload support files and a new version ------------------------
    support_file_id = create_support_file(session, project_id, 'sample/support_files/styles.css.gz')

    stream = File.open("#{File.expand_path(Rails.root)}/test/fixtures/sample/with_ignores/proj2.xml", 'rb')
    support_file_ids = { 355 => support_file_id }
    listener = XmlRevisionChanger.new('Hotdog', 'veryfirst', revision_id, support_file_ids)
    parser = REXML::Parsers::StreamParser.new(stream, listener)
    parser.parse
    stream.close

    fullpath = "#{File.expand_path(Rails.root)}/test/fixtures/sample/Initial/produced.xml.gz"
    Zlib::GzipWriter.open(fullpath) do |gz|
      gz.write(listener.result)
    end
    files_to_delete << fullpath

    # puts "uploaded support file #{support_file_id}"
    # create a project file that includes the correct support file ID
    if false
      f = File.open("#{File.expand_path(Rails.root)}/test/fixtures/sample/Initial/PB.xml", 'rb')
      txt = f.read
      txt = txt.gsub('$SUPPORT_FILE_ID', String(support_file_id))
      txt = txt.gsub('$REV_ID', String(revision_id))
      fullpath = "#{File.expand_path(Rails.root)}/test/fixtures/sample/Initial/produced.xml.gz"
      Zlib::GzipWriter.open(fullpath) do |gz|
        gz.write(txt)
      end
      files_to_delete << fullpath
    end
    # upload this project file (upload version)
    version_id = create_version(session, project_id, revision_id, 'sample/Initial/produced.xml.gz')
    version = ::Version.find(version_id)
    assert_equal 5, version.statistics.count

    revision.reload

    assert revision.get_stats

    creation_time = Time.now - 10
    revision.versions[0].chgtime = creation_time
    revision.versions[0].save!
    creation_time = revision.versions[0].chgtime

    # a second upload is not possible any more
    create_version(session, project_id, revision_id, 'sample/Initial/produced.xml.gz', false)

    # update should be possible
    update_version(session, project_id, revision_id, version_id, 'sample/Initial/produced.xml.gz')
    revision.versions[0].reload
    assert((creation_time - revision.versions[0].chgtime).abs > 0)

    # ---------------- back to project setup ------------------------
    # update the project's description
    description = 'Some very interesting story'
    xml_http_request(:post, url_for(controller: :revisions, action: :edit_description,
                                    project_id: project_id, id: revision_id),
                     session: session, req: 'save', revision: { description: description })
    assert_response :success
    revision.reload
    assert_equal description, revision.description

    # update the project's source language
    source_language = 1

    project.reload
    revision.reload
    assert_equal(source_language, revision.language_id, 'Source language ID did not update')
    assert_not_equal(0, revision.lang_word_count(revision.language),
                     'Word count cannot be zero after source language has been selected')

    changenum = assert_track_changes(session, changenum, "Changenum didn't increment after project settings updated")

    # setup the required revision details
    # revision conditions
    xml_http_request(:post, url_for(controller: :revisions, action: :edit_conditions),
                     session: session, req: 'save', project_id: project_id, id: revision_id,
                     revision: { max_bid: 0.1, max_bid_currency: 1, bidding_duration: 10, project_completion_duration: 12,
                                 word_count: 1 })
    assert_response :success
    assert_nil assigns(:warning)

    # languages
    xml_http_request(:post, url_for(controller: :revisions, action: :edit_languages),
                     session: session, project_id: project_id, id: revision_id, req: 'save',
                     language: { '2' => '1', '3' => '1', '4' => '1' })
    assert_response :success

    # release this revision
    xml_http_request(:post, url_for(controller: :revisions, action: :edit_release_status),
                     session: session, project_id: project_id, id: revision_id, req: 'show')
    assert_response :success
    assert_nil assigns(:warnings)
    changenum = assert_track_changes(session, changenum, "Changenum didn't increment after revision was released")

    # hide this revision
    xml_http_request(:post, url_for(controller: :revisions, action: :edit_release_status),
                     session: session, project_id: project_id, id: revision_id, req: 'hide')
    assert_response :success
    assert_nil assigns(:warnings)
    changenum = assert_track_changes(session, changenum, "Changenum didn't increment after revision was hidden")

    # release this revision
    xml_http_request(:post, url_for(controller: :revisions, action: :edit_release_status),
                     session: session, project_id: project_id, id: revision_id, req: 'show')
    assert_response :success
    assert_nil assigns(:warnings)
    changenum = assert_track_changes(session, changenum, "Changenum didn't increment after revision was released")

    check_emails_delivered(0)

    # Disable reviews
    revision.revision_languages.each do |rl|
      post disable_managed_work_url(rl.managed_work, format: :js)
      assert_response :success
      assert !rl.managed_work.reload.enabled?
    end

    # ------------------------------ translator bidding ----------------------------

    # log in as a translator
    translator = users(:orit)
    xsession = login(translator)
    assert_nil find_user_account(translator, 1)

    # make sure translator can see this project
    get(url_for(controller: :revisions, action: :show),
        session: xsession, project_id: project_id, id: revision_id)
    assert_response :success

    # initialize the translator's change number
    xchangenum = get_track_num(xsession)

    # create a chat in this revision
    chat_id = create_chat(xsession, project_id, revision_id)
    chat = Chat.find(chat_id)

    changenum = assert_track_changes(session, changenum, "Client changenum didn't increment after chat started")
    # xchangenum = assert_track_changes(xsession, xchangenum, "Translator changenum didn't increment after chat started")

    # allow the translator access to this revision
    xml_http_request(:post, url_for(controller: :chats, action: :set_access, project_id: project_id,
                                    revision_id: revision_id, id: chat_id),
                     session: session)
    chat.reload
    assert_response :success
    assert_equal chat.translator_has_access, 1

    changenum = assert_track_changes(session, changenum,
                                     "Client changenum didn't increment after translator was given access")
    xchangenum = assert_track_changes(xsession, xchangenum,
                                      "Translator changenum didn't increment after translator was given access")

    lang_id = 2
    # translator starts bid
    xml_http_request(:post, url_for(controller: :chats, action: :edit_bid, project_id: project_id,
                                    revision_id: revision_id, id: chat_id),
                     session: xsession, lang_id: lang_id)
    assert_response :success

    # translator saves the bid
    xml_http_request(:post, url_for(controller: :chats, action: :save_bid, project_id: project_id,
                                    revision_id: revision_id, id: chat_id),
                     session: xsession, bid: { amount: MINIMUM_BID_AMOUNT }, do_save: '1', lang_id: lang_id)
    assert_response :success
    bid = Bid.first
    assert_equal BID_GIVEN, bid.status
    check_emails_delivered(1)

    changenum = assert_track_changes(session, changenum,
                                     "Client changenum didn't increment after translator was given access")
    xchangenum = assert_track_changes(xsession, xchangenum,
                                      "Translator changenum didn't increment after translator was given access")

    # ------ another translator bids, this translator should get a "didn't win" message

    # log in as a translator
    translator2 = users(:guy)
    xsession2 = login(translator2)

    # make sure translator can see this project
    get(url_for(controller: :revisions, action: :show),
        session: xsession2, project_id: project_id, id: revision_id)
    assert_response :success

    # create a chat in this revision
    chat2_id = create_chat(xsession2, project_id, revision_id)
    chat2 = Chat.find(chat2_id)

    # translator starts bid
    xml_http_request(:post, url_for(controller: :chats, action: :edit_bid, project_id: project_id,
                                    revision_id: revision_id, id: chat2_id),
                     session: xsession, lang_id: lang_id)
    assert_response :success

    # translator saves the bid
    xml_http_request(:post, url_for(controller: :chats, action: :save_bid, project_id: project_id,
                                    revision_id: revision_id, id: chat2_id),
                     session: xsession2, bid: { amount: MINIMUM_BID_AMOUNT }, do_save: '1', lang_id: lang_id)
    assert_response :success
    bid2 = Bid.all.to_a[-1]
    assert_equal translator2, bid2.chat.translator
    assert_equal BID_GIVEN, bid2.status
    check_emails_delivered(1)

    # ------ client accepts the first transltor's bid

    client_balance = get_account_balance(client_account)

    client_reminder = Reminder.find_by(owner: bid.id, normal_user: client)
    assert client_reminder
    assert_equal client_reminder.event, EVENT_NEW_BID

    # --------------- client accepts bid -----------------
    # initialize the session variables
    get(url_for(controller: :chats, action: :show, project_id: project_id, revision_id: revision_id, id: chat_id),
        session: session)
    assert_response :success

    # select bid to accept
    bid_amount = MINIMUM_BID_AMOUNT
    xml_http_request(:post, url_for(controller: :chats, action: :accept_bid, project_id: project_id,
                                    revision_id: revision_id, id: chat_id),
                     session: session, bid: { amount: bid_amount }, do_save: '1', lang_id: lang_id, bid_id: bid.id)
    assert_response :success

    # 1st attempt, try to accept the bid without agreeing to the conditions
    xml_http_request(:post, url_for(controller: :chats, action: :transfer_bid_payment, project_id: project_id,
                                    revision_id: revision_id, id: chat_id),
                     session: session, accept: {})
    assert_response :success
    assert assigns(:warning)

    # accept the bid
    accept_list = {}
    idx = 1
    ChatsController::BID_ACCEPT_CONDITIONS.each do
      accept_list[idx] = '1'
      idx += 1
    end
    xml_http_request(:post, url_for(controller: :chats, action: :transfer_bid_payment, project_id: project_id,
                                    revision_id: revision_id, id: chat_id, bid_id: bid.id),
                     session: session, accept: accept_list)
    assert_response :success
    assert_nil assigns(:warning)
    bid.reload
    assert_equal BID_ACCEPTED, bid.status
    check_emails_delivered(2) # one to the winning translator and one to the losing

    client_reminder = Reminder.where("(owner_type='Bid') AND (owner_id=?) AND (normal_user_id=?)", bid.id, client.id).first
    assert_nil client_reminder

    translator_reminder = Reminder.where("(owner_type='Bid') AND (owner_id=?) AND (normal_user_id=?)", bid.id, translator.id).first
    assert translator_reminder
    assert_equal translator_reminder.event, EVENT_BID_ACCEPTED

    changenum = assert_track_changes(session, changenum,
                                     "Client changenum didn't increment after client accepted the bid")
    xchangenum = assert_track_changes(xsession, xchangenum,
                                      "Translator changenum didn't increment after client accepted the bid")

    work_total = bid_amount * revision.lang_word_count(revision.language)
    assert_not_equal 0, work_total

    client_account.reload
    paid = client_balance - get_account_balance(client_account)
    assert_same_amount(paid, work_total)

    bid_account = bid.account
    assert bid_account
    assert_same_amount(bid_account.balance, paid)

    # --------------- Translator downloads client version ----------
    get(url_for(controller: :versions, action: :show, project_id: project_id, revision_id: revision_id,
                id: revision.versions[0].id, format: 'xml'),
        session: xsession)
    assert_response :success

    # create something in the client's glossary, to verify we can see it
    glossary_term = GlossaryTerm.new(language_id: 1, txt: 'house', description: 'place we live')
    glossary_term.client = client
    glossary_term.save!

    # translator views client's glossary
    get(url_for(controller: :glossary_terms, action: :index, user_id: client.id, format: 'xml'),
        session: xsession)
    assert_response :success

    xml = get_xml_tree(@response.body)
    assert_element_attribute('house', xml.root.elements['glossary_terms/glossary_term'], 'txt')

    # see that the bid acceptance reminder has been automatically removed
    translator_reminder = Reminder.where("(owner_type='Bid') AND (owner_id=?) AND (normal_user_id=?)", bid.id, translator.id).first
    assert_nil translator_reminder

    # --------------- Translator uploads a version -----------------

    # translator does first upload
    trans_version_id = create_version(xsession, project_id, revision_id, 'sample/Initial/produced.xml.gz')
    changenum = assert_track_changes(session, changenum, "Client changenum didn't increment after translator uploaded a version")
    check_emails_delivered(1)

    # translator does second upload
    trans_version_id = create_version(xsession, project_id, revision_id, 'sample/Initial/produced.xml.gz')
    changenum = assert_track_changes(session, changenum, "Client changenum didn't increment after translator uploaded a version")
    check_emails_delivered(1)

    # translator cannot update uploaded version
    update_version(xsession, project_id, revision_id, trans_version_id, 'sample/Initial/produced.xml.gz', false)

    # create a new version, all texts are completed
    # ---------------- upload support files and a new version ------------------------
    # create a project file that includes the correct support file ID
    stream = File.open("#{File.expand_path(Rails.root)}/test/fixtures/sample/with_ignores/proj2_complete.xml", 'rb')
    support_file_ids = { 355 => support_file_id }
    listener = XmlRevisionChanger.new('Hotdog', 'veryfirst', revision_id, support_file_ids)
    parser = REXML::Parsers::StreamParser.new(stream, listener)
    parser.parse
    stream.close

    fullpath = "#{File.expand_path(Rails.root)}/test/fixtures/sample/Initial/produced_complete.xml.gz"
    Zlib::GzipWriter.open(fullpath) do |gz|
      gz.write(listener.result)
    end
    files_to_delete << fullpath

    prev_tu_count = Tu.count
    # puts "before tranlator upload: #{Tu.count} TUs"
    client.reload
    assert_equal 0, client.tus.count
    assert_equal 0, translator.tus.count
    Tu.all.each do |tu|
      assert_nil tu.translator
    end

    # Tu.all.each { |tu| puts "tu.#{tu.id} / #{tu.signature}: from_lang.#{tu.from_language.id}, to_lang.#{tu.to_language_id}, text: #{tu.original}" }

    # translator does third upload with all sentences complete
    trans_version_id = create_version(xsession, project_id, revision_id, 'sample/Initial/produced_complete.xml.gz')
    changenum = assert_track_changes(session, changenum, "Client changenum didn't increment after translator uploaded a version")
    check_emails_delivered(1)

    assert_equal prev_tu_count + 2, Tu.count
    translator.reload
    client.reload
    assert_equal 2, client.tus.count
    assert_equal 2, translator.tus.count
    # puts "\n\nAfter tranlator upload: #{Tu.count} TUs"
    # Tu.all.each { |tu| puts "tu.#{tu.id} / #{tu.signature}: from_lang.#{tu.from_language.id}, to_lang.#{tu.to_language_id}, text: #{tu.original}" }

    # now, declare the work as done

    prev_reminder_count = Reminder.count

    xml_http_request(:post, url_for(controller: :chats, action: :declare_done,
                                    project_id: bid.chat.revision.project_id,
                                    revision_id: bid.chat.revision_id, id: bid.chat.id),
                     lang_id: bid.revision_language.language_id, bid_id: bid.id)
    assert_response :success

    bid.reload
    assert_equal BID_DECLARED_DONE, bid.status

    check_emails_delivered(1) # the client gets a notification

    assert_equal prev_reminder_count + 1, Reminder.count
    reminder = Reminder.order('id DESC').first
    assert reminder
    assert_equal client.id, reminder.normal_user_id
    assert_equal EVENT_WORK_DONE, reminder.event
    reminder_revision_language = reminder.owner

    # same upload, see that no new reminder is created for the completed language
    trans_version_id = create_version(xsession, project_id, revision_id, 'sample/Initial/produced_complete.xml.gz')
    changenum = assert_track_changes(session, changenum, "Client changenum didn't increment after translator uploaded a version")
    check_emails_delivered(1)

    # check that another reminder was not created
    assert_equal prev_reminder_count + 1, Reminder.count

    # --------------- post messages back and forth -------------------
    create_message(xsession, project_id, revision_id, chat_id, 'This is a test message from the translator', [client])
    changenum = assert_track_changes(session, changenum, "Client changenum didn't increment after translator posted a message")
    xchangenum = assert_track_changes(xsession, xchangenum, "Translator changenum didn't increment after translator posted a message")
    check_emails_delivered(1)

    translator_reminder = Reminder.where("(owner_type='Chat') AND (owner_id=?) AND (normal_user_id=?)", chat_id, translator.id).first
    assert_nil translator_reminder
    client_reminder = Reminder.where("(owner_type='Chat') AND (owner_id=?) AND (normal_user_id=?)", chat_id, client.id).first
    assert client_reminder
    assert_equal client_reminder.event, EVENT_NEW_MESSAGE

    create_message(session, project_id, revision_id, chat_id, 'This is a test message from the client', [translator])
    changenum = assert_track_changes(session, changenum, "Client changenum didn't increment after client posted a message")
    xchangenum = assert_track_changes(xsession, xchangenum, "Translator changenum didn't increment after client posted a message")
    check_emails_delivered(1)

    translator_reminder = Reminder.where("(owner_type='Chat') AND (owner_id=?) AND (normal_user_id=?)", chat_id, translator.id).first
    assert translator_reminder
    assert_equal translator_reminder.event, EVENT_NEW_MESSAGE
    client_reminder = Reminder.where("(owner_type='Chat') AND (owner_id=?) AND (normal_user_id=?)", chat_id, client.id).first
    assert_nil client_reminder

    # --------------- client finalizes bid -----------------
    # initialize the session variables
    get(url_for(controller: :chats, action: :show, project_id: project_id, revision_id: revision_id, id: chat_id),
        session: session)
    assert_response :success

    # select bid to finalize
    xml_http_request(:post, url_for(controller: :chats, action: :finalize_bid, project_id: project_id,
                                    revision_id: revision_id, id: chat_id),
                     session: session, bid_id: bid.id)
    assert_response :success

    # try to finalize without accepting the conditions
    xml_http_request(:post, url_for(controller: :chats, action: :finalize_bids, project_id: project_id,
                                    revision_id: revision_id, id: chat_id),
                     session: session, accept: {}, bid_id: bid.id)
    assert_response :success
    assert assigns(:warning)

    # finalize selected bids
    accept_list = {}
    idx = 1
    ChatsController::BID_FINALIZE_CONDITIONS.each do
      accept_list[idx] = '1'
      idx += 1
    end
    xml_http_request(:post, url_for(controller: :chats, action: :finalize_bids, project_id: project_id,
                                    revision_id: revision_id, id: chat_id),
                     session: session, accept: accept_list, bid_id: bid.id)
    assert_response :success
    assert_nil assigns(:warning)
    bid.reload
    assert_equal BID_COMPLETED, bid.status
    check_emails_delivered(1)

    bid_account.reload
    client_account.reload
    translator_account = find_user_account(translator, 1)
    assert translator_account

    # find the root account, where the fee is going to
    root_account = RootAccount.where('currency_id=?', bid.currency_id).first
    assert root_account

    # make sure old reminders are cleared, and the only reminaining reminder is the work completion reminder for the translator
    client_bid_reminder = Reminder.where("(owner_type='Bid') AND (owner_id=?) AND (normal_user_id=?)", bid.id, client.id).first
    assert_nil client_bid_reminder

    client_rl_reminder = Reminder.where("(owner_type='RevisionLanguage') AND (owner_id=?) AND (normal_user_id=?)",
                                        reminder_revision_language.id, client.id).first
    assert_nil client_rl_reminder

    translator_reminders = Reminder.where("(owner_type='Bid') AND (owner_id=?) AND (normal_user_id=?)", bid.id, translator.id)
    assert_equal translator_reminders.length, 1
    assert_equal translator_reminders[0].event, EVENT_BID_COMPLETED

    # make sure that there are no message remiders left over too
    client_reminder = Reminder.where("(owner_type='Chat') AND (owner_id=?) AND (normal_user_id=?)", chat.id, client.id).first
    assert_nil client_reminder

    translator_reminder = Reminder.where("(owner_type='Chat') AND (owner_id=?) AND (normal_user_id=?)", chat.id, translator.id).first
    assert_nil translator_reminder

    # check that the escrow amount when to the translator, was deducted from the client and the bid account is empty
    root_account.reload

    assert_same_amount(translator_account.balance, paid * (1 - FEE_RATE))
    assert_same_amount(root_account.balance, paid * FEE_RATE)
    assert_same_amount(client_account.balance, client_balance - paid)
    assert_equal bid_account.balance, 0

    changenum = assert_track_changes(session, changenum, "Client changenum didn't increment after client finalized the bid")
    xchangenum = assert_track_changes(xsession, xchangenum, "Translator changenum didn't increment after client finalized the bid")

    # remove the (temporary) generated file from the test directory
    # File.delete("#{File.expand_path(Rails.root)}/test/fixtures/sample/Initial/produced.xml.gz")
    files_to_delete.each { |file_to_delete| File.delete(file_to_delete) }

    check_client_pages(client, session)
    check_translator_pages(translator, xsession)

    logout(session)
    logout(xsession)
  end

  def test_translation_with_review

    # make sure we start clean
    clear_all

    init_email_deliveries

    files_to_delete = []

    # ------------------------------ client project setup ----------------------------

    # log in as a client
    client = users(:amir)
    session = login(client)

    client_account = find_user_account(client, 1)
    assert client_account

    # create a project
    project_id = create_project(session, 'Dummy proj')
    project = Project.find(project_id)

    changenum = get_track_num(session)

    # create a new revision
    revision_id = create_revision(session, project_id, 'Created by test')
    revision = Revision.find(revision_id)
    changenum = assert_track_changes(session, changenum, "Changenum didn't increment after revision was created")
    assert_nil revision.get_stats

    # ---------------- upload support files and a new version ------------------------
    support_file_id = create_support_file(session, project_id, 'sample/support_files/styles.css.gz')

    stream = File.open("#{File.expand_path(Rails.root)}/test/fixtures/sample/with_ignores/proj2.xml", 'rb')
    support_file_ids = { 355 => support_file_id }
    listener = XmlRevisionChanger.new('Hotdog', 'veryfirst', revision_id, support_file_ids)
    parser = REXML::Parsers::StreamParser.new(stream, listener)
    parser.parse
    stream.close

    fullpath = "#{File.expand_path(Rails.root)}/test/fixtures/sample/Initial/produced.xml.gz"
    Zlib::GzipWriter.open(fullpath) do |gz|
      gz.write(listener.result)
    end
    files_to_delete << fullpath

    # puts "uploaded support file #{support_file_id}"
    # create a project file that includes the correct support file ID
    if false
      f = File.open("#{File.expand_path(Rails.root)}/test/fixtures/sample/Initial/PB.xml", 'rb')
      txt = f.read
      txt = txt.gsub('$SUPPORT_FILE_ID', String(support_file_id))
      txt = txt.gsub('$REV_ID', String(revision_id))
      fullpath = "#{File.expand_path(Rails.root)}/test/fixtures/sample/Initial/produced.xml.gz"
      Zlib::GzipWriter.open(fullpath) do |gz|
        gz.write(txt)
      end
      files_to_delete << fullpath
    end
    # upload this project file (upload version)
    version_id = create_version(session, project_id, revision_id, 'sample/Initial/produced.xml.gz')
    version = ::Version.find(version_id)
    assert_equal 5, version.statistics.count

    revision.reload

    assert revision.get_stats

    creation_time = Time.now - 10
    revision.versions[0].chgtime = creation_time
    revision.versions[0].save!
    creation_time = revision.versions[0].chgtime

    # update should be possible
    update_version(session, project_id, revision_id, version_id, 'sample/Initial/produced.xml.gz')
    revision.versions[0].reload
    assert((creation_time - revision.versions[0].chgtime).abs > 0)

    # ---------------- back to project setup ------------------------
    # update the project's description
    description = 'Some very interesting story'
    xml_http_request(:post, url_for(controller: :revisions, action: :edit_description, project_id: project_id,
                                    id: revision_id),
                     session: session, req: 'save', revision: { description: description })
    assert_response :success
    revision.reload
    assert_equal description, revision.description

    # update the project's source language
    source_language = 1

    project.reload
    revision.reload
    assert_equal(source_language, revision.language_id, 'Source language ID did not update')
    assert_not_equal(0, revision.lang_word_count(revision.language),
                     'Word count cannot be zero after source language has been selected')

    changenum = assert_track_changes(session, changenum, "Changenum didn't increment after project settings updated")

    # setup the required revision details
    # revision conditions
    xml_http_request(:post, url_for(controller: :revisions, action: :edit_conditions),
                     session: session, req: 'save', project_id: project_id, id: revision_id,
                     revision: { max_bid: 0.5, max_bid_currency: 1, bidding_duration: 10, project_completion_duration: 12,
                                 word_count: 1 })
    assert_response :success

    # languages
    xml_http_request(:post, url_for(controller: :revisions, action: :edit_languages),
                     session: session, project_id: project_id, id: revision_id, req: 'save',
                     language: { '2' => '1', '3' => '1', '4' => '1' })
    assert_response :success

    # release this revision
    xml_http_request(:post, url_for(controller: :revisions, action: :edit_release_status),
                     session: session, project_id: project_id, id: revision_id, req: 'show')
    assert_response :success
    assert_nil assigns(:warnings)
    changenum = assert_track_changes(session, changenum, "Changenum didn't increment after revision was released")

    check_emails_delivered(0)

    # ------------------------------ translator bidding ----------------------------

    # log in as a translator
    translator = users(:orit)
    xsession = login(translator)
    assert_nil find_user_account(translator, 1)

    # make sure translator can see this project
    get(url_for(controller: :revisions, action: :show),
        session: xsession, project_id: project_id, id: revision_id)
    assert_response :success

    # initialize the translator's change number
    xchangenum = get_track_num(xsession)

    # create a chat in this revision
    chat_id = create_chat(xsession, project_id, revision_id)
    chat = Chat.find(chat_id)

    changenum = assert_track_changes(session, changenum, "Client changenum didn't increment after chat started")
    # xchangenum = assert_track_changes(xsession, xchangenum, "Translator changenum didn't increment after chat started")

    # allow the translator access to this revision
    xml_http_request(:post, url_for(controller: :chats, action: :set_access, project_id: project_id,
                                    revision_id: revision_id, id: chat_id),
                     session: session)
    chat.reload
    assert_response :success
    assert_equal chat.translator_has_access, 1

    changenum = assert_track_changes(session, changenum, "Client changenum didn't increment after translator was given access")
    xchangenum = assert_track_changes(xsession, xchangenum, "Translator changenum didn't increment after translator was given access")

    bid_amount = 0.4

    lang_id = 2
    # translator starts bid
    xml_http_request(:post, url_for(controller: :chats, action: :edit_bid, project_id: project_id,
                                    revision_id: revision_id, id: chat_id),
                     session: xsession, lang_id: lang_id)
    assert_response :success

    # translator saves the bid
    xml_http_request(:post, url_for(controller: :chats, action: :save_bid, project_id: project_id,
                                    revision_id: revision_id, id: chat_id),
                     session: xsession, bid: { amount: bid_amount }, do_save: '1', lang_id: lang_id)
    assert_response :success
    bid = Bid.first
    assert_equal BID_GIVEN, bid.status
    check_emails_delivered(1)

    changenum = assert_track_changes(session, changenum,
                                     "Client changenum didn't increment after translator was given access")
    xchangenum = assert_track_changes(xsession, xchangenum,
                                      "Translator changenum didn't increment after translator was given access")

    # ------ client accepts the first transltor's bid

    client_balance = get_account_balance(client_account)

    client_reminder = Reminder.where("(owner_type='Bid') AND (owner_id=?) AND (normal_user_id=?)", bid.id, client.id).first
    assert client_reminder
    assert_equal client_reminder.event, EVENT_NEW_BID

    # --------------- client accepts bid -----------------
    # initialize the session variables
    get(url_for(controller: :chats, action: :show, project_id: project_id, revision_id: revision_id, id: chat_id),
        session: session)
    assert_response :success

    # select bid to accept
    xml_http_request(:post, url_for(controller: :chats, action: :accept_bid, project_id: project_id,
                                    revision_id: revision_id, id: chat_id),
                     session: session, bid: { amount: bid_amount }, do_save: '1', lang_id: lang_id, bid_id: bid.id)
    assert_response :success

    # accept the bid
    accept_list = {}
    idx = 1
    ChatsController::BID_ACCEPT_CONDITIONS.each do
      accept_list[idx] = '1'
      idx += 1
    end
    xml_http_request(:post, url_for(controller: :chats, action: :transfer_bid_payment, project_id: project_id,
                                    revision_id: revision_id, id: chat_id, bid_id: bid.id),
                     session: session, accept: accept_list)
    assert_response :success
    assert_nil assigns(:warning)
    bid.reload
    assert_equal BID_ACCEPTED, bid.status
    check_emails_delivered(1)

    client_reminder = Reminder.where("(owner_type='Bid') AND (owner_id=?) AND (normal_user_id=?)", bid.id, client.id).first
    assert_nil client_reminder

    translator_reminder = Reminder.where("(owner_type='Bid') AND (owner_id=?) AND (normal_user_id=?)", bid.id, translator.id).first
    assert translator_reminder
    assert_equal translator_reminder.event, EVENT_BID_ACCEPTED

    changenum = assert_track_changes(session, changenum, "Client changenum didn't increment after client accepted the bid")
    xchangenum = assert_track_changes(xsession, xchangenum, "Translator changenum didn't increment after client accepted the bid")

    work_total = bid_amount * revision.lang_word_count(revision.language)
    assert_not_equal 0, work_total

    client_account.reload
    paid = client_balance - get_account_balance(client_account)
    assert_same_amount(paid, work_total * 1.5) # include the payment for the review

    bid_account = bid.account
    assert bid_account
    assert_same_amount(bid_account.balance, paid)

    # --------------- Translator downloads client version ----------
    get(url_for(controller: :versions, action: :show, project_id: project_id, revision_id: revision_id,
                id: revision.versions[0].id, format: 'xml'),
        session: xsession)
    assert_response :success

    # create something in the client's glossary, to verify we can see it
    glossary_term = GlossaryTerm.new(language_id: 1, txt: 'house', description: 'place we live')
    glossary_term.client = client
    glossary_term.save!

    # translator views client's glossary
    get(url_for(controller: :glossary_terms, action: :index, user_id: client.id, format: 'xml'),
        session: xsession)
    assert_response :success

    xml = get_xml_tree(@response.body)
    assert_element_attribute('house', xml.root.elements['glossary_terms/glossary_term'], 'txt')

    # see that the bid acceptance reminder has been automatically removed
    translator_reminder = Reminder.where("(owner_type='Bid') AND (owner_id=?) AND (normal_user_id=?)", bid.id, translator.id).first
    assert_nil translator_reminder

    # --------------- Reviewer downloads client version ----------

    logout(xsession)

    reviewer = users(:guy)
    rsession = login(reviewer)

    # first, the reviewer needs to be the reviewer
    revision.revision_languages.each do |rl|
      post(url_for(controller: :managed_works, action: :be_reviewer, id: rl.managed_work.id))
      assert_response :redirect

      rl.managed_work.reload
      assert_equal reviewer, rl.managed_work.translator

      assert_equal MANAGED_WORK_CREATED, rl.managed_work.translation_status
    end

    get(url_for(controller: :chats, action: :show, project_id: project_id, revision_id: revision_id,
                id: chat_id, format: 'xml'))
    assert_response :success

    xml = get_xml_tree(@response.body)

    get(url_for(controller: :versions, action: :show, project_id: project_id, revision_id: revision_id,
                id: revision.versions[0].id, format: 'xml'))
    assert_response :success

    xml = get_xml_tree(@response.body)

    get(url_for(controller: :versions, action: :show, project_id: project_id, revision_id: revision_id,
                id: revision.versions[0].id))
    assert_response :success

    xsession = login(translator)

    # --------------- Translator uploads a version -----------------

    # translator does first upload
    trans_version_id = create_version(xsession, project_id, revision_id, 'sample/Initial/produced.xml.gz')
    changenum = assert_track_changes(session, changenum, "Client changenum didn't increment after translator uploaded a version")
    check_emails_delivered(1) # not completed yet, only client is notified

    # create a new version, all texts are completed
    # ---------------- upload support files and a new version ------------------------
    # create a project file that includes the correct support file ID
    stream = File.open("#{File.expand_path(Rails.root)}/test/fixtures/sample/with_ignores/proj2_complete.xml", 'rb')
    support_file_ids = { 355 => support_file_id }
    listener = XmlRevisionChanger.new('Hotdog', 'veryfirst', revision_id, support_file_ids)
    parser = REXML::Parsers::StreamParser.new(stream, listener)
    parser.parse
    stream.close

    fullpath = "#{File.expand_path(Rails.root)}/test/fixtures/sample/Initial/produced_complete.xml.gz"
    Zlib::GzipWriter.open(fullpath) do |gz|
      gz.write(listener.result)
    end
    files_to_delete << fullpath

    prev_reminder_count = Reminder.count
    # translator does third upload with all sentences complete
    trans_version_id = create_version(xsession, project_id, revision_id, 'sample/Initial/produced_complete.xml.gz')
    changenum = assert_track_changes(session, changenum, "Client changenum didn't increment after translator uploaded a version")
    check_emails_delivered(1) # completed reviesion

    revision.revision_languages.each do |rl|
      # puts "after upload: #{managed_work.owner.language.name}=>#{managed_work.translation_status}"
      # Spanish is fully translated
      if rl.managed_work.owner.language.name == 'Spanish'

        selected_bid = rl.selected_bid

        xml_http_request(:post, url_for(controller: :chats, action: :declare_done,
                                        project_id: selected_bid.chat.revision.project_id,
                                        revision_id: selected_bid.chat.revision_id, id: selected_bid.chat.id),
                         lang_id: bid.revision_language.language_id, bid_id: bid.id)
        assert_response :success

        check_emails_delivered(2) # both the client and reviewer are notified

        selected_bid.reload
        rl.managed_work.reload

        assert_equal BID_DECLARED_DONE, selected_bid.status
        assert_equal MANAGED_WORK_REVIEWING, rl.managed_work.translation_status
      else
        rl.managed_work.reload
        assert_equal MANAGED_WORK_CREATED, rl.managed_work.translation_status
      end
    end

    # --- reviewer downloads the translator's version ---

    logout(xsession)
    rsession = login(reviewer)

    get(url_for(controller: :versions, action: :index, project_id: project_id, revision_id: revision_id,
                alternate_user_id: translator.id, format: 'xml'))
    assert_response :success

    versions = assigns('versions')
    assert versions
    assert versions.collect(&:id).include?(trans_version_id)

    # xml = get_xml_tree(@response.body)
    # puts xml

    get(url_for(controller: :versions, action: :show, project_id: project_id, revision_id: revision_id,
                id: trans_version_id, format: 'xml'))
    assert_response :success

    version = assigns('version')
    assert version
    assert_equal trans_version_id, version.id

    # xml = get_xml_tree(@response.body)
    # puts xml

    # -- reviewer completes the review --
    # check that the reviewer can access
    get(url_for(controller: :chats, action: :show, project_id: project.id, revision_id: revision.id, id: chat_id))
    assert_response :success

    assert assigns('is_reviewer')

    # now, indicate that the review is complete
    xml_http_request(:post, url_for(controller: :chats, action: :review_complete, project_id: project.id,
                                    revision_id: revision.id, id: chat_id, bid_id: bid.id))
    assert_response :success

    check_emails_delivered(0)

    # finalize selected bids
    accept_list = {}
    idx = 1
    ChatsController::BID_REVIEW_CONDITIONS.each do
      accept_list[idx] = '1'
      idx += 1
    end
    xml_http_request(:post, url_for(controller: :chats, action: :finalize_review, project_id: project.id,
                                    revision_id: revision.id, id: chat_id),
                     accept: accept_list, bid_id: bid.id)
    assert_response :success
    assert_nil assigns(:warning)

    check_emails_delivered(1)

    managed_work = bid.revision_language.managed_work
    managed_work.reload
    assert_equal MANAGED_WORK_WAITING_FOR_PAYMENT, managed_work.translation_status

    # the client gets a reminder about the work completed
    assert_equal prev_reminder_count + 1, Reminder.count
    reminder = Reminder.order('id DESC').first
    assert reminder
    assert_equal client.id, reminder.normal_user_id
    assert_equal EVENT_WORK_DONE, reminder.event
    reminder_revision_language = reminder.owner

    logout(rsession)
    xsession = login(translator)

    # --------------- post messages back and forth -------------------
    create_message(xsession, project_id, revision_id, chat_id, 'This is a test message from the translator', [client])
    changenum = assert_track_changes(session, changenum, "Client changenum didn't increment after translator posted a message")
    xchangenum = assert_track_changes(xsession, xchangenum, "Translator changenum didn't increment after translator posted a message")
    check_emails_delivered(1)

    translator_reminder = Reminder.where("(owner_type='Chat') AND (owner_id=?) AND (normal_user_id=?)", chat_id, translator.id).first
    assert_nil translator_reminder
    client_reminder = Reminder.where("(owner_type='Chat') AND (owner_id=?) AND (normal_user_id=?)", chat_id, client.id).first
    assert client_reminder
    assert_equal client_reminder.event, EVENT_NEW_MESSAGE

    create_message(session, project_id, revision_id, chat_id, 'This is a test message from the client', [translator])
    changenum = assert_track_changes(session, changenum, "Client changenum didn't increment after client posted a message")
    xchangenum = assert_track_changes(xsession, xchangenum, "Translator changenum didn't increment after client posted a message")
    check_emails_delivered(1)

    translator_reminder = Reminder.where("(owner_type='Chat') AND (owner_id=?) AND (normal_user_id=?)", chat_id, translator.id).first
    assert translator_reminder
    assert_equal translator_reminder.event, EVENT_NEW_MESSAGE
    client_reminder = Reminder.where("(owner_type='Chat') AND (owner_id=?) AND (normal_user_id=?)", chat_id, client.id).first
    assert_nil client_reminder

    # --------------- client finalizes bid -----------------
    # initialize the session variables
    get(url_for(controller: :chats, action: :show, project_id: project_id, revision_id: revision_id, id: chat_id),
        session: session)
    assert_response :success

    # select bid to finalize
    xml_http_request(:post, url_for(controller: :chats, action: :finalize_bid, project_id: project_id,
                                    revision_id: revision_id, id: chat_id),
                     session: session, bid_id: bid.id)
    assert_response :success

    # try to finalize without accepting the conditions
    xml_http_request(:post, url_for(controller: :chats, action: :finalize_bids, project_id: project_id,
                                    revision_id: revision_id, id: chat_id),
                     session: session, accept: {}, bid_id: bid.id)
    assert_response :success
    assert assigns(:warning)

    # finalize selected bids
    accept_list = {}
    idx = 1
    ChatsController::BID_FINALIZE_CONDITIONS.each do
      accept_list[idx] = '1'
      idx += 1
    end
    xml_http_request(:post, url_for(controller: :chats, action: :finalize_bids, project_id: project_id,
                                    revision_id: revision_id, id: chat_id),
                     session: session, accept: accept_list, bid_id: bid.id)
    assert_response :success
    assert_nil assigns(:warning)
    bid.reload
    assert_equal BID_COMPLETED, bid.status
    check_emails_delivered(1)

    bid_account.reload
    client_account.reload
    translator_account = find_user_account(translator, 1)
    assert translator_account

    # find the root account, where the fee is going to
    root_account = RootAccount.where('currency_id=?', bid.currency_id).first
    assert root_account

    # make sure old reminders are cleared, and the only reminaining reminder is the work completion reminder for the translator
    client_bid_reminder = Reminder.where("(owner_type='Bid') AND (owner_id=?) AND (normal_user_id=?)", bid.id, client.id).first
    assert_nil client_bid_reminder

    client_rl_reminder = Reminder.where("(owner_type='RevisionLanguage') AND (owner_id=?) AND (normal_user_id=?)",
                                        reminder_revision_language.id, client.id).first
    assert_nil client_rl_reminder

    translator_reminders = Reminder.where("(owner_type='Bid') AND (owner_id=?) AND (normal_user_id=?)", bid.id, translator.id)
    assert_equal translator_reminders.length, 1
    assert_equal translator_reminders[0].event, EVENT_BID_COMPLETED

    # make sure that there are no message remiders left over too
    client_reminder = Reminder.where("(owner_type='Chat') AND (owner_id=?) AND (normal_user_id=?)", chat.id, client.id).first
    assert_nil client_reminder

    translator_reminder = Reminder.where("(owner_type='Chat') AND (owner_id=?) AND (normal_user_id=?)", chat.id, translator.id).first
    assert_nil translator_reminder

    # check that the escrow amount when to the translator, was deducted from the client and the bid account is empty
    root_account.reload

    assert_same_amount(translator_account.balance, work_total * (1 - FEE_RATE))
    assert_same_amount(root_account.balance, work_total * FEE_RATE * 1.5)
    assert_same_amount(client_account.balance, client_balance - paid)
    assert_same_amount(bid_account.balance, 0) # work_total * 0.5

    changenum = assert_track_changes(session, changenum, "Client changenum didn't increment after client finalized the bid")
    xchangenum = assert_track_changes(xsession, xchangenum, "Translator changenum didn't increment after client finalized the bid")

    # remove the (temporary) generated file from the test directory
    # File.delete("#{File.expand_path(Rails.root)}/test/fixtures/sample/Initial/produced.xml.gz")
    files_to_delete.each { |file_to_delete| File.delete(file_to_delete) }

    check_client_pages(client, session)
    check_translator_pages(translator, xsession)

    logout(session)
    logout(xsession)
  end

  def test_review_after_translation

    # make sure we start clean
    clear_all

    init_email_deliveries

    files_to_delete = []

    # ------------------------------ client project setup ----------------------------

    # log in as a client
    client = users(:amir)
    session = login(client)

    client_account = find_user_account(client, 1)
    assert client_account

    # create a project
    project_id = create_project(session, 'Dummy proj')
    project = Project.find(project_id)

    changenum = get_track_num(session)

    # create a new revision
    revision_id = create_revision(session, project_id, 'Created by test')
    revision = Revision.find(revision_id)
    changenum = assert_track_changes(session, changenum, "Changenum didn't increment after revision was created")
    assert_nil revision.get_stats

    # ---------------- upload support files and a new version ------------------------
    support_file_id = create_support_file(session, project_id, 'sample/support_files/styles.css.gz')

    stream = File.open("#{File.expand_path(Rails.root)}/test/fixtures/sample/with_ignores/proj2.xml", 'rb')
    support_file_ids = { 355 => support_file_id }
    listener = XmlRevisionChanger.new('Hotdog', 'veryfirst', revision_id, support_file_ids)
    parser = REXML::Parsers::StreamParser.new(stream, listener)
    parser.parse
    stream.close

    fullpath = "#{File.expand_path(Rails.root)}/test/fixtures/sample/Initial/produced.xml.gz"
    Zlib::GzipWriter.open(fullpath) do |gz|
      gz.write(listener.result)
    end
    files_to_delete << fullpath

    # puts "uploaded support file #{support_file_id}"
    # create a project file that includes the correct support file ID
    if false
      f = File.open("#{File.expand_path(Rails.root)}/test/fixtures/sample/Initial/PB.xml", 'rb')
      txt = f.read
      txt = txt.gsub('$SUPPORT_FILE_ID', String(support_file_id))
      txt = txt.gsub('$REV_ID', String(revision_id))
      fullpath = "#{File.expand_path(Rails.root)}/test/fixtures/sample/Initial/produced.xml.gz"
      Zlib::GzipWriter.open(fullpath) do |gz|
        gz.write(txt)
      end
      files_to_delete << fullpath
    end
    # upload this project file (upload version)
    version_id = create_version(session, project_id, revision_id, 'sample/Initial/produced.xml.gz')
    version = ::Version.find(version_id)
    assert_equal 5, version.statistics.count

    revision.reload

    assert revision.get_stats

    creation_time = Time.now - 10
    revision.versions[0].chgtime = creation_time
    revision.versions[0].save!
    creation_time = revision.versions[0].chgtime

    # update should be possible
    update_version(session, project_id, revision_id, version_id, 'sample/Initial/produced.xml.gz')
    revision.versions[0].reload
    assert((creation_time - revision.versions[0].chgtime).abs > 0)

    # ---------------- back to project setup ------------------------
    # update the project's description
    description = 'Some very interesting story'
    xml_http_request(:post, url_for(controller: :revisions, action: :edit_description, project_id: project_id,
                                    id: revision_id),
                     session: session, req: 'save', revision: { description: description })
    assert_response :success
    revision.reload
    assert_equal description, revision.description

    # update the project's source language
    source_language = 1

    project.reload
    revision.reload
    assert_equal(source_language, revision.language_id, 'Source language ID did not update')
    assert_not_equal(0, revision.lang_word_count(revision.language), 'Word count cannot be zero after source language has been selected')

    changenum = assert_track_changes(session, changenum, "Changenum didn't increment after project settings updated")

    # setup the required revision details
    # revision conditions
    xml_http_request(:post, url_for(controller: :revisions, action: :edit_conditions),
                     session: session, req: 'save', project_id: project_id, id: revision_id,
                     revision: { max_bid: 0.5, max_bid_currency: 1, bidding_duration: 10, project_completion_duration: 12,
                                 word_count: 1 })
    assert_response :success

    # languages
    xml_http_request(:post, url_for(controller: :revisions, action: :edit_languages),
                     session: session, project_id: project_id, id: revision_id, req: 'save',
                     language: { '2' => '1', '3' => '1', '4' => '1' })
    assert_response :success

    # release this revision
    xml_http_request(:post, url_for(controller: :revisions, action: :edit_release_status),
                     session: session, project_id: project_id, id: revision_id, req: 'show')
    assert_response :success
    assert_nil assigns(:warnings)
    changenum = assert_track_changes(session, changenum, "Changenum didn't increment after revision was released")

    check_emails_delivered(0)

    # enable review
    # now it starts enabled

    # revision.revision_languages.each do |rl|
    # assert rl.managed_work
    # assert_equal MANAGED_WORK_INACTIVE,rl.managed_work.active
    # assert_nil rl.managed_work.translator

    # post(url_for(:controller=>:managed_works, :action=>:update_status, :id=>rl.managed_work.id, :active=>MANAGED_WORK_ACTIVE))
    # assert_response :success
    #
    # rl.managed_work.reload
    # assert_equal MANAGED_WORK_ACTIVE,rl.managed_work.active
    # end

    # ------------------------------ translator bidding ----------------------------

    # log in as a translator
    translator = users(:orit)
    xsession = login(translator)
    assert_nil find_user_account(translator, 1)

    # make sure translator can see this project
    get(url_for(controller: :revisions, action: :show),
        session: xsession, project_id: project_id, id: revision_id)
    assert_response :success

    # initialize the translator's change number
    xchangenum = get_track_num(xsession)

    # create a chat in this revision
    chat_id = create_chat(xsession, project_id, revision_id)
    chat = Chat.find(chat_id)

    changenum = assert_track_changes(session, changenum, "Client changenum didn't increment after chat started")
    # xchangenum = assert_track_changes(xsession, xchangenum, "Translator changenum didn't increment after chat started")

    # allow the translator access to this revision
    xml_http_request(:post, url_for(controller: :chats, action: :set_access, project_id: project_id,
                                    revision_id: revision_id, id: chat_id),
                     session: session)
    chat.reload
    assert_response :success
    assert_equal chat.translator_has_access, 1

    changenum = assert_track_changes(session, changenum, "Client changenum didn't increment after translator was given access")
    xchangenum = assert_track_changes(xsession, xchangenum, "Translator changenum didn't increment after translator was given access")

    bid_amount = 0.4

    lang_id = 2
    # translator starts bid
    xml_http_request(:post, url_for(controller: :chats, action: :edit_bid, project_id: project_id,
                                    revision_id: revision_id, id: chat_id),
                     session: xsession, lang_id: lang_id)
    assert_response :success

    # translator saves the bid
    xml_http_request(:post, url_for(controller: :chats, action: :save_bid, project_id: project_id,
                                    revision_id: revision_id, id: chat_id),
                     session: xsession, bid: { amount: bid_amount }, do_save: '1', lang_id: lang_id)
    assert_response :success
    bid = Bid.first
    assert_equal BID_GIVEN, bid.status
    check_emails_delivered(1)

    changenum = assert_track_changes(session, changenum, "Client changenum didn't increment after translator was given access")
    xchangenum = assert_track_changes(xsession, xchangenum, "Translator changenum didn't increment after translator was given access")

    # ------ client accepts the first transltor's bid

    client_balance = get_account_balance(client_account)

    client_reminder = Reminder.where("(owner_type='Bid') AND (owner_id=?) AND (normal_user_id=?)", bid.id, client.id).first
    assert client_reminder
    assert_equal client_reminder.event, EVENT_NEW_BID

    # --------------- client accepts bid -----------------
    # initialize the session variables
    get(url_for(controller: :chats, action: :show, project_id: project_id, revision_id: revision_id, id: chat_id),
        session: session)
    assert_response :success

    # select bid to accept
    xml_http_request(:post, url_for(controller: :chats, action: :accept_bid, project_id: project_id,
                                    revision_id: revision_id, id: chat_id),
                     session: session, bid: { amount: bid_amount }, do_save: '1', lang_id: lang_id, bid_id: bid.id)
    assert_response :success

    # accept the bid
    accept_list = {}
    idx = 1
    ChatsController::BID_ACCEPT_CONDITIONS.each do
      accept_list[idx] = '1'
      idx += 1
    end
    xml_http_request(:post, url_for(controller: :chats, action: :transfer_bid_payment, project_id: project_id,
                                    revision_id: revision_id, id: chat_id, bid_id: bid.id),
                     session: session, accept: accept_list)
    assert_response :success
    assert_nil assigns(:warning)
    bid.reload
    assert_equal BID_ACCEPTED, bid.status
    check_emails_delivered(1)

    client_reminder = Reminder.where("(owner_type='Bid') AND (owner_id=?) AND (normal_user_id=?)", bid.id, client.id).first
    assert_nil client_reminder

    translator_reminder = Reminder.where("(owner_type='Bid') AND (owner_id=?) AND (normal_user_id=?)", bid.id, translator.id).first
    assert translator_reminder
    assert_equal translator_reminder.event, EVENT_BID_ACCEPTED

    changenum = assert_track_changes(session, changenum, "Client changenum didn't increment after client accepted the bid")
    xchangenum = assert_track_changes(xsession, xchangenum, "Translator changenum didn't increment after client accepted the bid")

    work_total = bid_amount * revision.lang_word_count(revision.language)
    assert_not_equal 0, work_total

    client_account.reload
    paid = client_balance - get_account_balance(client_account)
    assert_same_amount(paid, work_total * 1.5) # include the payment for the review

    bid_account = bid.account
    assert bid_account
    assert_same_amount(bid_account.balance, paid)

    # --------------- Translator downloads client version ----------
    get(url_for(controller: :versions, action: :show, project_id: project_id, revision_id: revision_id,
                id: revision.versions[0].id, format: 'xml'),
        session: xsession)
    assert_response :success

    # create something in the client's glossary, to verify we can see it
    glossary_term = GlossaryTerm.new(language_id: 1, txt: 'house', description: 'place we live')
    glossary_term.client = client
    glossary_term.save!

    # translator views client's glossary
    get(url_for(controller: :glossary_terms, action: :index, user_id: client.id, format: 'xml'),
        session: xsession)
    assert_response :success

    xml = get_xml_tree(@response.body)
    assert_element_attribute('house', xml.root.elements['glossary_terms/glossary_term'], 'txt')

    # see that the bid acceptance reminder has been automatically removed
    translator_reminder = Reminder.where("(owner_type='Bid') AND (owner_id=?) AND (normal_user_id=?)", bid.id, translator.id).first
    assert_nil translator_reminder

    # --------------- Translator uploads a version -----------------

    # translator does first upload
    trans_version_id = create_version(xsession, project_id, revision_id, 'sample/Initial/produced.xml.gz')
    changenum = assert_track_changes(session, changenum, "Client changenum didn't increment after translator uploaded a version")
    check_emails_delivered(1) # not completed yet, only client is notified

    # create a new version, all texts are completed
    # ---------------- upload support files and a new version ------------------------
    # create a project file that includes the correct support file ID
    stream = File.open("#{File.expand_path(Rails.root)}/test/fixtures/sample/with_ignores/proj2_complete.xml", 'rb')
    support_file_ids = { 355 => support_file_id }
    listener = XmlRevisionChanger.new('Hotdog', 'veryfirst', revision_id, support_file_ids)
    parser = REXML::Parsers::StreamParser.new(stream, listener)
    parser.parse
    stream.close

    fullpath = "#{File.expand_path(Rails.root)}/test/fixtures/sample/Initial/produced_complete.xml.gz"
    Zlib::GzipWriter.open(fullpath) do |gz|
      gz.write(listener.result)
    end
    files_to_delete << fullpath

    prev_reminder_count = Reminder.count
    # translator does third upload with all sentences complete
    trans_version_id = create_version(xsession, project_id, revision_id, 'sample/Initial/produced_complete.xml.gz')
    changenum = assert_track_changes(session, changenum, "Client changenum didn't increment after translator uploaded a version")
    check_emails_delivered(1) # completed reviesion. no reviewer to notify yet

    revision.revision_languages.each do |rl|

      bid = rl.selected_bid
      if bid
        # translator declares as complete
        xml_http_request(:post, url_for(controller: :chats, action: :declare_done,
                                        project_id: bid.chat.revision.project_id,
                                        revision_id: bid.chat.revision_id, id: bid.chat.id),
                         lang_id: bid.revision_language.language_id, bid_id: bid.id)
        assert_response :success

        bid.reload
        assert_equal BID_DECLARED_DONE, bid.status

        check_emails_delivered(1) # completed reviesion. no reviewer to notify yet

      end

      rl.managed_work.reload

      # Spanish is fully translated
      if rl.managed_work.owner.language.name == 'Spanish'
        assert_equal MANAGED_WORK_WAITING_FOR_REVIEWER, rl.managed_work.translation_status
      else
        assert_equal MANAGED_WORK_CREATED, rl.managed_work.translation_status
      end
    end

    assert_equal prev_reminder_count + 1, Reminder.count
    reminder = Reminder.order('id DESC').first
    assert reminder
    assert_equal client.id, reminder.normal_user_id
    assert_equal EVENT_WORK_DONE, reminder.event
    reminder_revision_language = reminder.owner

    # check that another reminder was not created
    assert_equal prev_reminder_count + 1, Reminder.count

    # --------------- Reviewer downloads client version ----------

    logout(xsession)

    reviewer = users(:guy)
    rsession = login(reviewer)

    # first, the reviewer needs to be the reviewer
    bid_to_complete = nil
    revision.revision_languages.each do |rl|
      post(url_for(controller: :managed_works, action: :be_reviewer, id: rl.managed_work.id))
      assert_response :redirect

      rl.managed_work.reload
      assert_equal reviewer, rl.managed_work.translator

      if rl.managed_work.owner.language.name == 'Spanish'
        assert_equal MANAGED_WORK_REVIEWING, rl.managed_work.translation_status
        bid_to_complete = rl.selected_bid
      else
        assert_equal MANAGED_WORK_CREATED, rl.managed_work.translation_status
      end
    end

    assert bid_to_complete

    get(url_for(controller: :chats, action: :show, project_id: project_id, revision_id: revision_id,
                id: chat_id, format: 'xml'))
    assert_response :success

    xml = get_xml_tree(@response.body)

    get(url_for(controller: :versions, action: :show, project_id: project_id, revision_id: revision_id,
                id: revision.versions[0].id, format: 'xml'))
    assert_response :success

    xml = get_xml_tree(@response.body)

    get(url_for(controller: :versions, action: :show, project_id: project_id, revision_id: revision_id,
                id: revision.versions[0].id))
    assert_response :success

    # --- reviewer downloads the translator's version ---

    get(url_for(controller: :versions, action: :index, project_id: project_id, revision_id: revision_id,
                alternate_user_id: translator.id, format: 'xml'))
    assert_response :success

    versions = assigns('versions')
    assert versions
    assert versions.collect(&:id).include?(trans_version_id)

    # xml = get_xml_tree(@response.body)
    # puts xml

    get(url_for(controller: :versions, action: :show, project_id: project_id, revision_id: revision_id,
                id: trans_version_id, format: 'xml'))
    assert_response :success

    version = assigns('version')
    assert version
    assert_equal trans_version_id, version.id

    # xml = get_xml_tree(@response.body)
    # puts xml

    # -- reviewer completes the review --
    # check that the reviewer can access
    get(url_for(controller: :chats, action: :show, project_id: project.id, revision_id: revision.id, id: chat_id))
    assert_response :success

    assert assigns('is_reviewer')

    # now, indicate that the review is complete
    xml_http_request(:post, url_for(controller: :chats, action: :review_complete, project_id: project.id,
                                    revision_id: revision.id, id: chat_id, bid_id: bid_to_complete.id))
    assert_response :success

    check_emails_delivered(0)

    # finalize selected bids
    accept_list = {}
    idx = 1
    ChatsController::BID_REVIEW_CONDITIONS.each do
      accept_list[idx] = '1'
      idx += 1
    end
    xml_http_request(:post, url_for(controller: :chats, action: :finalize_review, project_id: project.id,
                                    revision_id: revision.id, id: chat_id),
                     accept: accept_list, bid_id: bid_to_complete.id)
    assert_response :success
    assert_nil assigns(:warning)

    check_emails_delivered(1)

    managed_work = bid_to_complete.revision_language.managed_work
    managed_work.reload
    assert_equal MANAGED_WORK_WAITING_FOR_PAYMENT, managed_work.translation_status

    logout(rsession)
    xsession = login(translator)

    # --------------- post messages back and forth -------------------
    create_message(xsession, project_id, revision_id, chat_id, 'This is a test message from the translator', [client])
    changenum = assert_track_changes(session, changenum, "Client changenum didn't increment after translator posted a message")
    xchangenum = assert_track_changes(xsession, xchangenum, "Translator changenum didn't increment after translator posted a message")
    check_emails_delivered(1)

    translator_reminder = Reminder.where("(owner_type='Chat') AND (owner_id=?) AND (normal_user_id=?)", chat_id, translator.id).first
    assert_nil translator_reminder
    client_reminder = Reminder.where("(owner_type='Chat') AND (owner_id=?) AND (normal_user_id=?)", chat_id, client.id).first
    assert client_reminder
    assert_equal client_reminder.event, EVENT_NEW_MESSAGE

    create_message(session, project_id, revision_id, chat_id, 'This is a test message from the client', [translator])
    changenum = assert_track_changes(session, changenum, "Client changenum didn't increment after client posted a message")
    xchangenum = assert_track_changes(xsession, xchangenum, "Translator changenum didn't increment after client posted a message")
    check_emails_delivered(1)

    translator_reminder = Reminder.where("(owner_type='Chat') AND (owner_id=?) AND (normal_user_id=?)", chat_id, translator.id).first
    assert translator_reminder
    assert_equal translator_reminder.event, EVENT_NEW_MESSAGE
    client_reminder = Reminder.where("(owner_type='Chat') AND (owner_id=?) AND (normal_user_id=?)", chat_id, client.id).first
    assert_nil client_reminder

    # --------------- client finalizes bid -----------------
    # initialize the session variables
    get(url_for(controller: :chats, action: :show, project_id: project_id, revision_id: revision_id, id: chat_id),
        session: session)
    assert_response :success

    # select bid to finalize
    xml_http_request(:post, url_for(controller: :chats, action: :finalize_bid, project_id: project_id,
                                    revision_id: revision_id, id: chat_id),
                     session: session, bid_id: bid_to_complete.id)
    assert_response :success

    # try to finalize without accepting the conditions
    xml_http_request(:post, url_for(controller: :chats, action: :finalize_bids, project_id: project_id,
                                    revision_id: revision_id, id: chat_id),
                     session: session, accept: {}, bid_id: bid_to_complete.id)
    assert_response :success
    assert assigns(:warning)

    # finalize selected bids
    accept_list = {}
    idx = 1
    ChatsController::BID_FINALIZE_CONDITIONS.each do
      accept_list[idx] = '1'
      idx += 1
    end
    xml_http_request(:post, url_for(controller: :chats, action: :finalize_bids, project_id: project_id,
                                    revision_id: revision_id, id: chat_id),
                     session: session, accept: accept_list, bid_id: bid_to_complete.id)
    assert_response :success
    assert_nil assigns(:warning)
    bid_to_complete.reload
    assert_equal BID_COMPLETED, bid_to_complete.status
    check_emails_delivered(1)

    bid_account.reload
    client_account.reload
    translator_account = find_user_account(translator, 1)
    assert translator_account

    # find the root account, where the fee is going to
    root_account = RootAccount.where('currency_id=?', bid_to_complete.currency_id).first
    assert root_account

    # make sure old reminders are cleared, and the only reminaining reminder is the work completion reminder for the translator
    client_bid_reminder = Reminder.where("(owner_type='Bid') AND (owner_id=?) AND (normal_user_id=?)", bid_to_complete.id, client.id).first
    assert_nil client_bid_reminder

    client_rl_reminder = Reminder.where("(owner_type='RevisionLanguage') AND (owner_id=?) AND (normal_user_id=?)", reminder_revision_language.id, client.id).first
    assert_nil client_rl_reminder

    translator_reminders = Reminder.where("(owner_type='Bid') AND (owner_id=?) AND (normal_user_id=?)", bid_to_complete.id, translator.id)
    assert_equal translator_reminders.length, 1
    assert_equal translator_reminders[0].event, EVENT_BID_COMPLETED

    # make sure that there are no message remiders left over too
    client_reminder = Reminder.where("(owner_type='Chat') AND (owner_id=?) AND (normal_user_id=?)", chat.id, client.id).first
    assert_nil client_reminder

    translator_reminder = Reminder.where("(owner_type='Chat') AND (owner_id=?) AND (normal_user_id=?)", chat.id, translator.id).first
    assert_nil translator_reminder

    # check that the escrow amount when to the translator, was deducted from the client and the bid account is empty
    root_account.reload

    assert_same_amount(translator_account.balance, work_total * (1 - FEE_RATE))
    assert_same_amount(root_account.balance, work_total * FEE_RATE * 1.5)
    assert_same_amount(client_account.balance, client_balance - paid)
    assert_same_amount(bid_account.balance, 0) # work_total * 0.5

    changenum = assert_track_changes(session, changenum, "Client changenum didn't increment after client finalized the bid")
    xchangenum = assert_track_changes(xsession, xchangenum, "Translator changenum didn't increment after client finalized the bid")

    # remove the (temporary) generated file from the test directory
    # File.delete("#{File.expand_path(Rails.root)}/test/fixtures/sample/Initial/produced.xml.gz")
    files_to_delete.each { |file_to_delete| File.delete(file_to_delete) }

    check_client_pages(client, session)
    check_translator_pages(translator, xsession)

    logout(session)
    logout(xsession)
  end

  def test_translation_and_separate_review

    # make sure we start clean
    clear_all

    init_email_deliveries

    files_to_delete = []

    # ------------------------------ client project setup ----------------------------

    # log in as a client
    client = users(:amir)
    session = login(client)

    client_account = find_user_account(client, 1)
    assert client_account

    # create a project
    project_id = create_project(session, 'Dummy proj')
    project = Project.find(project_id)

    changenum = get_track_num(session)

    # create a new revision
    revision_id = create_revision(session, project_id, 'Created by test')
    revision = Revision.find(revision_id)
    changenum = assert_track_changes(session, changenum, "Changenum didn't increment after revision was created")
    assert_nil revision.get_stats

    # ---------------- upload support files and a new version ------------------------
    support_file_id = create_support_file(session, project_id, 'sample/support_files/styles.css.gz')

    stream = File.open("#{File.expand_path(Rails.root)}/test/fixtures/sample/with_ignores/proj2.xml", 'rb')
    support_file_ids = { 355 => support_file_id }
    listener = XmlRevisionChanger.new('Hotdog', 'veryfirst', revision_id, support_file_ids)
    parser = REXML::Parsers::StreamParser.new(stream, listener)
    parser.parse
    stream.close

    fullpath = "#{File.expand_path(Rails.root)}/test/fixtures/sample/Initial/produced.xml.gz"
    Zlib::GzipWriter.open(fullpath) do |gz|
      gz.write(listener.result)
    end
    files_to_delete << fullpath

    # puts "uploaded support file #{support_file_id}"
    # create a project file that includes the correct support file ID
    if false
      f = File.open("#{File.expand_path(Rails.root)}/test/fixtures/sample/Initial/PB.xml", 'rb')
      txt = f.read
      txt = txt.gsub('$SUPPORT_FILE_ID', String(support_file_id))
      txt = txt.gsub('$REV_ID', String(revision_id))
      fullpath = "#{File.expand_path(Rails.root)}/test/fixtures/sample/Initial/produced.xml.gz"
      Zlib::GzipWriter.open(fullpath) do |gz|
        gz.write(txt)
      end
      files_to_delete << fullpath
    end
    # upload this project file (upload version)
    version_id = create_version(session, project_id, revision_id, 'sample/Initial/produced.xml.gz')
    version = ::Version.find(version_id)
    assert_equal 5, version.statistics.count

    revision.reload

    assert revision.get_stats

    creation_time = Time.now - 10
    revision.versions[0].chgtime = creation_time
    revision.versions[0].save!
    creation_time = revision.versions[0].chgtime

    # update should be possible
    update_version(session, project_id, revision_id, version_id, 'sample/Initial/produced.xml.gz')
    revision.versions[0].reload
    assert((creation_time - revision.versions[0].chgtime).abs > 0)

    # ---------------- back to project setup ------------------------
    # update the project's description
    description = 'Some very interesting story'
    xml_http_request(:post, url_for(controller: :revisions, action: :edit_description, project_id: project_id, id: revision_id),
                     session: session, req: 'save', revision: { description: description })
    assert_response :success
    revision.reload
    assert_equal description, revision.description

    # update the project's source language
    source_language = 1

    project.reload
    revision.reload
    assert_equal(source_language, revision.language_id, 'Source language ID did not update')
    assert_not_equal(0, revision.lang_word_count(revision.language), 'Word count cannot be zero after source language has been selected')

    changenum = assert_track_changes(session, changenum, "Changenum didn't increment after project settings updated")

    # setup the required revision details
    # revision conditions
    xml_http_request(:post, url_for(controller: :revisions, action: :edit_conditions),
                     session: session, req: 'save', project_id: project_id, id: revision_id,
                     revision: { max_bid: 0.5, max_bid_currency: 1, bidding_duration: 10, project_completion_duration: 12,
                                 word_count: 1 })
    assert_response :success

    # languages
    xml_http_request(:post, url_for(controller: :revisions, action: :edit_languages),
                     session: session, project_id: project_id, id: revision_id, req: 'save',
                     language: { '2' => '1', '3' => '1', '4' => '1' })
    assert_response :success

    # release this revision
    xml_http_request(:post, url_for(controller: :revisions, action: :edit_release_status),
                     session: session, project_id: project_id, id: revision_id, req: 'show')
    assert_response :success
    assert_nil assigns(:warnings)
    changenum = assert_track_changes(session, changenum, "Changenum didn't increment after revision was released")

    check_emails_delivered(0)

    # REVIEW: should be active
    revision.revision_languages.each do |rl|
      assert rl.managed_work
      assert_equal MANAGED_WORK_PENDING_PAYMENT, rl.managed_work.active
      assert_nil rl.managed_work.translator
    end

    # Activate all reviews
    # revision.revision_languages.each do |rl|
    #  post(enable_manage_works_path(rl.managed_work))
    #  assert (:success)
    #  assert rl.managed_work.reload.pending_payment?
    # end

    # ------------------------------ translator bidding ----------------------------

    # log in as a translator
    translator = users(:orit)
    xsession = login(translator)
    assert_nil find_user_account(translator, 1)

    # make sure translator can see this project
    get(url_for(controller: :revisions, action: :show),
        session: xsession, project_id: project_id, id: revision_id)
    assert_response :success

    # initialize the translator's change number
    xchangenum = get_track_num(xsession)

    # create a chat in this revision
    chat_id = create_chat(xsession, project_id, revision_id)
    chat = Chat.find(chat_id)

    changenum = assert_track_changes(session, changenum, "Client changenum didn't increment after chat started")
    # xchangenum = assert_track_changes(xsession, xchangenum, "Translator changenum didn't increment after chat started")

    # allow the translator access to this revision
    xml_http_request(:post, url_for(controller: :chats, action: :set_access, project_id: project_id,
                                    revision_id: revision_id, id: chat_id),
                     session: session)
    chat.reload
    assert_response :success
    assert_equal chat.translator_has_access, 1

    changenum = assert_track_changes(session, changenum, "Client changenum didn't increment after translator was given access")
    xchangenum = assert_track_changes(xsession, xchangenum, "Translator changenum didn't increment after translator was given access")

    bid_amount = 0.4

    lang_id = 2
    # translator starts bid
    xml_http_request(:post, url_for(controller: :chats, action: :edit_bid, project_id: project_id,
                                    revision_id: revision_id, id: chat_id),
                     session: xsession, lang_id: lang_id)
    assert_response :success

    # translator saves the bid
    xml_http_request(:post, url_for(controller: :chats, action: :save_bid, project_id: project_id,
                                    revision_id: revision_id, id: chat_id),
                     session: xsession, bid: { amount: bid_amount }, do_save: '1', lang_id: lang_id)
    assert_response :success
    bid = Bid.first
    assert_equal BID_GIVEN, bid.status
    check_emails_delivered(1)

    changenum = assert_track_changes(session, changenum, "Client changenum didn't increment after translator was given access")
    xchangenum = assert_track_changes(xsession, xchangenum, "Translator changenum didn't increment after translator was given access")

    # ------ client accepts the first transltor's bid

    client_balance = get_account_balance(client_account)

    client_reminder = Reminder.where("(owner_type='Bid') AND (owner_id=?) AND (normal_user_id=?)", bid.id, client.id).first
    assert client_reminder
    assert_equal client_reminder.event, EVENT_NEW_BID

    # --------------- client accepts bid -----------------
    # initialize the session variables
    get(url_for(controller: :chats, action: :show, project_id: project_id, revision_id: revision_id, id: chat_id),
        session: session)
    assert_response :success

    # select bid to accept
    xml_http_request(:post, url_for(controller: :chats, action: :accept_bid, project_id: project_id,
                                    revision_id: revision_id, id: chat_id),
                     session: session, bid: { amount: bid_amount }, do_save: '1', lang_id: lang_id, bid_id: bid.id)
    assert_response :success

    # accept the bid
    accept_list = {}
    idx = 1
    ChatsController::BID_ACCEPT_CONDITIONS.each do
      accept_list[idx] = '1'
      idx += 1
    end
    xml_http_request(:post, url_for(controller: :chats, action: :transfer_bid_payment, project_id: project_id,
                                    revision_id: revision_id, id: chat_id, bid_id: bid.id),
                     session: session, accept: accept_list)
    assert_response :success
    assert_nil assigns(:warning)
    bid.reload
    assert_equal BID_ACCEPTED, bid.status
    check_emails_delivered(1)

    client_reminder = Reminder.where("(owner_type='Bid') AND (owner_id=?) AND (normal_user_id=?)", bid.id, client.id).first
    assert_nil client_reminder

    translator_reminder = Reminder.where("(owner_type='Bid') AND (owner_id=?) AND (normal_user_id=?)", bid.id, translator.id).first
    assert translator_reminder
    assert_equal translator_reminder.event, EVENT_BID_ACCEPTED

    changenum = assert_track_changes(session, changenum, "Client changenum didn't increment after client accepted the bid")
    xchangenum = assert_track_changes(xsession, xchangenum, "Translator changenum didn't increment after client accepted the bid")

    translator_amount = bid_amount * revision.lang_word_count(revision.language)
    work_total = translator_amount * 1.5
    assert_not_equal 0, work_total

    client_account.reload
    paid = client_balance - get_account_balance(client_account)
    assert_same_amount(paid, work_total) # no review payment

    bid_account = bid.account
    assert bid_account
    assert_same_amount(bid_account.balance, paid)

    # --------------- Translator downloads client version ----------
    get(url_for(controller: :versions, action: :show, project_id: project_id, revision_id: revision_id,
                id: revision.versions[0].id, format: 'xml'),
        session: xsession)
    assert_response :success

    # create something in the client's glossary, to verify we can see it
    glossary_term = GlossaryTerm.new(language_id: 1, txt: 'house', description: 'place we live')
    glossary_term.client = client
    glossary_term.save!

    # translator views client's glossary
    get(url_for(controller: :glossary_terms, action: :index, user_id: client.id, format: 'xml'),
        session: xsession)
    assert_response :success

    xml = get_xml_tree(@response.body)
    assert_element_attribute('house', xml.root.elements['glossary_terms/glossary_term'], 'txt')

    # see that the bid acceptance reminder has been automatically removed
    translator_reminder = Reminder.where("(owner_type='Bid') AND (owner_id=?) AND (normal_user_id=?)", bid.id, translator.id).first
    assert_nil translator_reminder

    # --------------- Translator uploads a version -----------------

    # translator does first upload
    trans_version_id = create_version(xsession, project_id, revision_id, 'sample/Initial/produced.xml.gz')
    changenum = assert_track_changes(session, changenum, "Client changenum didn't increment after translator uploaded a version")
    check_emails_delivered(1) # not completed yet, only client is notified

    # create a new version, all texts are completed
    # ---------------- upload support files and a new version ------------------------
    # create a project file that includes the correct support file ID
    stream = File.open("#{File.expand_path(Rails.root)}/test/fixtures/sample/with_ignores/proj2_complete.xml", 'rb')
    support_file_ids = { 355 => support_file_id }
    listener = XmlRevisionChanger.new('Hotdog', 'veryfirst', revision_id, support_file_ids)
    parser = REXML::Parsers::StreamParser.new(stream, listener)
    parser.parse
    stream.close

    fullpath = "#{File.expand_path(Rails.root)}/test/fixtures/sample/Initial/produced_complete.xml.gz"
    Zlib::GzipWriter.open(fullpath) do |gz|
      gz.write(listener.result)
    end
    files_to_delete << fullpath

    prev_reminder_count = Reminder.count
    # translator does third upload with all sentences complete
    trans_version_id = create_version(xsession, project_id, revision_id, 'sample/Initial/produced_complete.xml.gz')
    changenum = assert_track_changes(session, changenum, "Client changenum didn't increment after translator uploaded a version")
    check_emails_delivered(1) # completed reviesion. no reviewer to notify yet

    selected_bid = nil
    # after translation is complete, the job is waiting for a reviewer
    revision.revision_languages.each do |rl|
      if rl.managed_work.owner.language.name == 'Spanish'

        selected_bid = rl.selected_bid

        xml_http_request(:post, url_for(controller: :chats, action: :declare_done,
                                        project_id: selected_bid.chat.revision.project_id,
                                        revision_id: selected_bid.chat.revision_id,
                                        id: selected_bid.chat.id),
                         lang_id: bid.revision_language.language_id, bid_id: bid.id)
        assert_response :success

        check_emails_delivered(1)

        selected_bid.reload
        rl.managed_work.reload

        assert_equal BID_DECLARED_DONE, selected_bid.status
        assert_equal MANAGED_WORK_WAITING_FOR_REVIEWER, rl.managed_work.translation_status
      else
        rl.managed_work.reload
        assert_equal MANAGED_WORK_CREATED, rl.managed_work.translation_status
      end
    end

    assert_equal prev_reminder_count + 1, Reminder.count
    reminder = Reminder.order('id DESC').first
    assert reminder
    assert_equal client.id, reminder.normal_user_id
    assert_equal EVENT_WORK_DONE, reminder.event
    reminder_revision_language = reminder.owner

    # check that another reminder was not created
    assert_equal prev_reminder_count + 1, Reminder.count

    logout(xsession)

    # Review is being paid along with the bid
    ### --- before the client pays for review, reviewer cannot take the job
    reviewer = users(:guy)
    ##
    # #rsession = login(reviewer)
    ##
    ### this job is closed, so the reviewer cannot take it
    # #revision.revision_languages.each do |rl|
    ##  #puts "checking revision language to #{rl.language.name} - rl.selected_bid=#{rl.selected_bid}"
    ##  assert_equal MANAGED_WORK_ACTIVE,rl.managed_work.active
    ##  assert_nil rl.managed_work.translator
    ##
    ##  post(url_for(:controller=>:managed_works, :action=>:be_reviewer, :id=>rl.managed_work.id))
    ##  assert_response :redirect
    ##
    ##  rl.managed_work.reload
    ##  assert_nil rl.managed_work.translator
    # #end
    ##
    # #logout(rsession)

    # --- client enables review

    session = login(client)

    managed_work = bid.revision_language.managed_work
    assert managed_work
    assert_equal MANAGED_WORK_ACTIVE, managed_work.active
    assert_nil managed_work.translator

    bid_account = bid.account
    assert_same_amount(work_total, bid_account.balance)

    get(url_for(controller: :chats, action: :show, project_id: project_id, revision_id: revision_id, id: chat_id),
        session: session)
    assert_response :success

    # Was already enabled and paid along with the bid
    ## enable review
    # xml_http_request(:post, url_for(:controller=>:chats, :action=>:enable_review, :project_id=>project_id, :revision_id=>revision_id, :id=>chat_id),
    # {:session=>session, :lang_id=>lang_id, :bid_id=>bid.id} )
    # assert_response :success

    # xml_http_request(:post, url_for(:controller=>:chats, :action=>:pay_for_review, :project_id=>project_id, :revision_id=>revision_id, :id=>chat_id),
    # {:session=>session, :managed_work_id => managed_work.id} )
    # assert_response :success
    # assert_nil assigns(:warning)

    # managed_work.reload
    # assert_equal MANAGED_WORK_ACTIVE,managed_work.active
    #
    # bid_account.reload
    # assert_same_amount(work_total*1.5,bid_account.balance)

    # still not assigned to a translator
    assert_nil managed_work.translator

    # puts "-- enabled review for #{managed_work.owner.language.name}"

    check_emails_delivered(0)

    # logout(session)

    # --------------- Reviewer downloads client version ----------
    rsession = login(reviewer)

    # this job is not open. the reviewer takes it
    post(url_for(controller: :managed_works, action: :be_reviewer, id: managed_work.id))
    assert_response :redirect

    managed_work.reload
    assert_equal reviewer, managed_work.translator

    get(url_for(controller: :chats, action: :show, project_id: project_id, revision_id: revision_id,
                id: chat_id, format: 'xml'))
    assert_response :success

    xml = get_xml_tree(@response.body)

    get(url_for(controller: :versions, action: :show, project_id: project_id, revision_id: revision_id,
                id: revision.versions[0].id, format: 'xml'))
    assert_response :success

    xml = get_xml_tree(@response.body)

    get(url_for(controller: :versions, action: :show, project_id: project_id, revision_id: revision_id,
                id: revision.versions[0].id))
    assert_response :success

    # --- reviewer downloads the translator's version ---

    get(url_for(controller: :versions, action: :index, project_id: project_id, revision_id: revision_id,
                alternate_user_id: translator.id, format: 'xml'))
    assert_response :success

    versions = assigns('versions')
    assert versions
    assert versions.collect(&:id).include?(trans_version_id)

    # xml = get_xml_tree(@response.body)
    # puts xml

    get(url_for(controller: :versions, action: :show, project_id: project_id, revision_id: revision_id,
                id: trans_version_id, format: 'xml'))
    assert_response :success

    version = assigns('version')
    assert version
    assert_equal trans_version_id, version.id

    # xml = get_xml_tree(@response.body)
    # puts xml

    # -- reviewer completes the review --
    # check that the reviewer can access
    get(url_for(controller: :chats, action: :show, project_id: project.id, revision_id: revision.id, id: chat_id))
    assert_response :success

    assert assigns('is_reviewer')

    # puts "finalizing review for #{bid.revision_language.language.name}"

    # now, indicate that the review is complete
    xml_http_request(:post, url_for(controller: :chats, action: :review_complete, project_id: project.id,
                                    revision_id: revision.id, id: chat_id, bid_id: bid.id))
    assert_response :success

    check_emails_delivered(0)

    # finalize selected bids
    accept_list = {}
    idx = 1
    ChatsController::BID_REVIEW_CONDITIONS.each do
      accept_list[idx] = '1'
      idx += 1
    end
    xml_http_request(:post, url_for(controller: :chats, action: :finalize_review, project_id: project.id,
                                    revision_id: revision.id, id: chat_id),
                     accept: accept_list, bid_id: bid.id)
    assert_response :success
    assert_nil assigns(:warning)

    check_emails_delivered(1)

    managed_work = bid.revision_language.managed_work
    managed_work.reload
    assert_equal MANAGED_WORK_WAITING_FOR_PAYMENT, managed_work.translation_status

    logout(rsession)
    xsession = login(translator)

    # --------------- post messages back and forth -------------------
    create_message(xsession, project_id, revision_id, chat_id, 'This is a test message from the translator', [client])
    check_emails_delivered(1)

    translator_reminder = Reminder.where("(owner_type='Chat') AND (owner_id=?) AND (normal_user_id=?)", chat_id, translator.id).first
    assert_nil translator_reminder
    client_reminder = Reminder.where("(owner_type='Chat') AND (owner_id=?) AND (normal_user_id=?)", chat_id, client.id).first
    assert client_reminder
    assert_equal client_reminder.event, EVENT_NEW_MESSAGE

    create_message(session, project_id, revision_id, chat_id, 'This is a test message from the client', [translator])
    check_emails_delivered(1)

    translator_reminder = Reminder.where("(owner_type='Chat') AND (owner_id=?) AND (normal_user_id=?)", chat_id, translator.id).first
    assert translator_reminder
    assert_equal translator_reminder.event, EVENT_NEW_MESSAGE
    client_reminder = Reminder.where("(owner_type='Chat') AND (owner_id=?) AND (normal_user_id=?)", chat_id, client.id).first
    assert_nil client_reminder

    # --------------- client finalizes bid -----------------
    # initialize the session variables
    get(url_for(controller: :chats, action: :show, project_id: project_id, revision_id: revision_id, id: chat_id),
        session: session)
    assert_response :success

    # select bid to finalize
    xml_http_request(:post, url_for(controller: :chats, action: :finalize_bid, project_id: project_id,
                                    revision_id: revision_id, id: chat_id),
                     session: session, bid_id: bid.id)
    assert_response :success

    # try to finalize without accepting the conditions
    xml_http_request(:post, url_for(controller: :chats, action: :finalize_bids, project_id: project_id,
                                    revision_id: revision_id, id: chat_id),
                     session: session, accept: {}, bid_id: bid.id)
    assert_response :success
    assert assigns(:warning)

    # finalize selected bids
    accept_list = {}
    idx = 1
    ChatsController::BID_FINALIZE_CONDITIONS.each do
      accept_list[idx] = '1'
      idx += 1
    end
    xml_http_request(:post, url_for(controller: :chats, action: :finalize_bids, project_id: project_id,
                                    revision_id: revision_id, id: chat_id),
                     session: session, accept: accept_list, bid_id: bid.id)
    assert_response :success
    assert_nil assigns(:warning)
    bid.reload
    assert_equal BID_COMPLETED, bid.status
    check_emails_delivered(1)

    bid_account.reload
    client_account.reload
    translator_account = find_user_account(translator, 1)
    assert translator_account

    # find the root account, where the fee is going to
    root_account = RootAccount.where('currency_id=?', bid.currency_id).first
    assert root_account

    # make sure old reminders are cleared, and the only reminaining reminder is the work completion reminder for the translator
    client_bid_reminder = Reminder.where("(owner_type='Bid') AND (owner_id=?) AND (normal_user_id=?)", bid.id, client.id).first
    assert_nil client_bid_reminder

    client_rl_reminder = Reminder.where("(owner_type='RevisionLanguage') AND (owner_id=?) AND (normal_user_id=?)", reminder_revision_language.id, client.id).first
    assert_nil client_rl_reminder

    translator_reminders = Reminder.where("(owner_type='Bid') AND (owner_id=?) AND (normal_user_id=?)", bid.id, translator.id)
    assert_equal translator_reminders.length, 1
    assert_equal translator_reminders[0].event, EVENT_BID_COMPLETED

    # make sure that there are no message remiders left over too
    client_reminder = Reminder.where("(owner_type='Chat') AND (owner_id=?) AND (normal_user_id=?)", chat.id, client.id).first
    assert_nil client_reminder

    translator_reminder = Reminder.where("(owner_type='Chat') AND (owner_id=?) AND (normal_user_id=?)", chat.id, translator.id).first
    assert_nil translator_reminder

    # check that the escrow amount when to the translator, was deducted from the client and the bid account is empty
    root_account.reload

    assert_same_amount(translator_account.balance, translator_amount * (1 - FEE_RATE))
    assert_same_amount(root_account.balance, work_total * FEE_RATE)
    assert_same_amount(client_account.balance, client_balance - paid)
    assert_same_amount(bid_account.balance, 0) # work_total * 0.5

    changenum = assert_track_changes(session, changenum, "Client changenum didn't increment after client finalized the bid")
    xchangenum = assert_track_changes(xsession, xchangenum, "Translator changenum didn't increment after client finalized the bid")

    # remove the (temporary) generated file from the test directory
    # File.delete("#{File.expand_path(Rails.root)}/test/fixtures/sample/Initial/produced.xml.gz")
    files_to_delete.each { |file_to_delete| File.delete(file_to_delete) }

    check_client_pages(client, session)
    check_translator_pages(translator, xsession)

    logout(session)
    logout(xsession)
  end

  def clear_all
    Project.delete_all
    Revision.delete_all
    RevisionLanguage.delete_all
    Chat.delete_all
    Message.delete_all
    Bid.delete_all
    ManagedWork.delete_all
    UserSession.delete_all
    Reminder.delete_all
    CmsRequest.delete_all
    Tu.delete_all
  end

end
