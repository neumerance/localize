def get_xml_tree(body)
  dat = StringIO.new(body)
  REXML::Document.new(dat)
end

def assert_element_text(value, element)
  assert element
  assert_equal value, element.text
end

def assert_element_attribute(value, element, attribute)
  assert element
  assert_equal value, element.attributes[attribute]
end

def assert_element_attribute_positive(element, attribute)
  assert element
  val = Integer(element.attributes[attribute])
  assert_not_equal val, 0
end

def get_element_attribute(element, attribute, ignore_nil = false)
  assert element
  assert element.attributes[attribute] unless ignore_nil
  element.attributes[attribute]
end

def get_element_text(element, ignore_nil = false)
  assert element
  assert element.text unless ignore_nil
  element.text
end

def params_with_session(user_fixture = :admin, params = {})
  user_session = user_sessions(user_fixture)
  params[:session] = user_session.session_num
  params
end

def login(user)
  post(
    url_for(controller: '/login', action: :login, format: 'xml'),
    params: {
      email: user.email,
      password: get_user_test_password(user),
      usertype: user[:type]
    }
  )
  assert_response :success
  xml = get_xml_tree(@response.body)
  assert_element_text(String(user.id), xml.root.elements['user_id'])
  get_element_text(xml.root.elements['session_num'])
end

def get_user_test_password(user)
  if user.password.present?
    user.password
  else
    config = YAML.load(ERB.new(File.read(Rails.root.join('test/fixtures/sample/reference/user_reference.yml.erb'))).result)
    config[user.nickname]['password']
  end
end

def logout(session)
  post(url_for(controller: :login, action: :logout, format: 'xml'),
       params: { session: session })
  assert_response :success
  xml = get_xml_tree(@response.body)
  assert_element_text('Logged out', xml.root.elements['status'])
end

def current_logout
  post(url_for(controller: :login, action: :logout))
  assert_response :success
end

def get_track_num(session)
  post(url_for(controller: :changes, action: :changenum, format: 'xml'),
       params: { session: session })
  assert_response :success
  xml = get_xml_tree(@response.body)
  Integer(get_element_text(xml.root.elements['counter']))
end

def assert_track_changes(session, _changenum, _fail_message)
  new_changenum = get_track_num(session)
  # assert_not_equal changenum, new_changenum, fail_message
  new_changenum
end

def assert_page_ok(url_args, params, do_htm = true)
  if do_htm
    get url_for(url_args), params: params
    assert_response :success
    return
  end

  get url_for(url_args.merge(format: 'xml')), params: params
  assert_response :success
end

def get_private_key(session)
  get(url_for(controller: :changes, action: :get_serial_num, format: 'xml'),
      params: { session: session })
  assert_response :success
  xml = get_xml_tree(@response.body)
  private_key = get_element_text(xml.root.elements['serial_number']).to_i
  assert_not_equal 0, private_key
  private_key
end

def create_project(session, name)
  private_key = get_private_key(session)

  post(url_for(controller: :projects, action: :create, format: 'xml'),
       params: { session: session, name: name, private_key: private_key, source: SOURCE_HM })

  assert_response :success
  xml = get_xml_tree(@response.body)

  assert_element_attribute('Project created', xml.root.elements['result'], 'message')
  proj_id = get_element_attribute(xml.root.elements['result'], 'id').to_i
  assert_not_equal 0, proj_id

  post(url_for(controller: :projects, action: :lookup_by_private_key, format: 'xml'),
       params: { session: session, private_key: private_key })
  assert_response :success
  # puts @response.body
  xml = get_xml_tree(@response.body)
  found_id = get_element_attribute(xml.root.elements['result'], 'id').to_i
  found_name = get_element_attribute(xml.root.elements['result'], 'name')
  assert_equal proj_id, found_id
  assert_equal name, found_name

  project = Project.find(proj_id)
  assert_equal SOURCE_HM, project.source

  proj_id
end

def create_revision(session, project_id, name, succeed = true, cms_request = nil)
  private_key = get_private_key(session)

  cms_request_id = cms_request ? cms_request.id : nil

  post(url_for(controller: :revisions, action: :create, project_id: project_id, format: 'xml'),
       params: { session: session, name: name, language_id: 1, private_key: private_key, cms_request_id: cms_request_id })
  assert_response :success
  xml = get_xml_tree(@response.body)
  if succeed
    # get the revision ID
    assert_element_attribute('Revision created', xml.root.elements['result'], 'message')
    rev_id = get_element_attribute(xml.root.elements['result'], 'id').to_i
    assert_not_equal 0, rev_id

    post(url_for(controller: :revisions, action: :lookup_by_private_key, format: 'xml'),
         params: { session: session, private_key: private_key })
    assert_response :success
    # puts @response.body
    xml = get_xml_tree(@response.body)
    found_id = get_element_attribute(xml.root.elements['result'], 'id').to_i
    found_name = get_element_attribute(xml.root.elements['result'], 'name')
    assert_equal rev_id, found_id
    assert_equal name, found_name

    # verify that the created page can be seen by both TA and humans
    assert_page_ok({ controller: :revisions, action: :show, project_id: project_id, id: rev_id },
                   params: { session: session })

    return rev_id
  else
    assert_element_text('Revision cannot be created in this project', xml.root.elements['status'])
  end
end

def create_support_file(session, project_id, fname)
  fdata = fixture_file_upload(fname, 'application/octet-stream')
  multipart_post url_for(controller: :support_files, action: :create, project_id: project_id, format: 'xml'),
                 session: session, support_file: { 'uploaded_data' => fdata }
  assert_response :success
  xml = get_xml_tree(@response.body)
  assert_element_attribute('Support_File created', xml.root.elements['result'], 'message')
  sf_id = get_element_attribute(xml.root.elements['result'], 'id').to_i
  assert_not_equal 0, sf_id

  assert_page_ok({ controller: :support_files, action: :show, project_id: project_id, id: sf_id },
                 params: { session: session })

  sf_id

end

def create_version(session, project_id, revision_id, fname, should_pass = true, expected_TAS_notifications = 0)
  fdata = fixture_file_upload(fname, 'application/octet-stream')
  expected = 'Version created'
  multipart_post url_for(controller: :versions, action: :create, project_id: project_id, revision_id: revision_id, format: 'xml'),
                 session: session, version: { 'uploaded_data' => fdata }
  assert_response :success
  xml = get_xml_tree(@response.body)

  assert assigns(:tas_completion_notification_sent)
  tas_completion_notification_sent = assigns(:tas_completion_notification_sent)
  assert_equal expected_TAS_notifications, tas_completion_notification_sent.length, tas_completion_notification_sent.join("\n")

  if should_pass
    assert_element_attribute(expected, xml.root.elements['result'], 'message')
    ver_id = get_element_attribute(xml.root.elements['result'], 'id').to_i
    assert_not_equal 0, ver_id

    assert_page_ok({ controller: :versions, action: :show, project_id: project_id, revision_id: revision_id, id: ver_id },
                   params: { session: session })

    return ver_id
  else
    res = get_element_attribute(xml.root.elements['result'], 'message')
    assert_not_equal res, expected
  end
end

def update_version(session, project_id, revision_id, version_id, fname, should_pass = true)
  fdata = fixture_file_upload(fname, 'application/octet-stream')
  expected = 'Version updated'
  multipart_post url_for(controller: :versions, action: :update, project_id: project_id, revision_id: revision_id, id: version_id, format: 'xml'),
                 :session => session, :version => { 'uploaded_data' => fdata }, '_method' => 'PUT'
  assert_response :success
  xml = get_xml_tree(@response.body)
  if should_pass
    assert_element_attribute(expected, xml.root.elements['result'], 'message')
    ver_id = get_element_attribute(xml.root.elements['result'], 'id').to_i
    assert_not_equal 0, ver_id

    assert_page_ok({ controller: :versions, action: :show, project_id: project_id, revision_id: revision_id, id: ver_id },
                   params: { session: session })

    return ver_id
  else
    res = get_element_attribute(xml.root.elements['result'], 'message')
    assert_not_equal res, expected
  end
end

def create_chat(session, project_id, revision_id, succeed = true)
  post(url_for(controller: :chats, action: :create, project_id: project_id, revision_id: revision_id, format: 'xml'),
       params: { session: session })
  assert_response :success
  xml = get_xml_tree(@response.body)
  if succeed
    assert_element_attribute('Chat created', xml.root.elements['result'], 'message')
    chat_id = get_element_attribute(xml.root.elements['result'], 'id').to_i
    assert_not_equal 0, chat_id

    assert_page_ok({ controller: :chats, action: :show, project_id: project_id, revision_id: revision_id, id: chat_id },
                   params: { session: session })

    return chat_id
  else
    assert_element_text('1', xml.root.elements['aborted'])
  end
end

def create_message(session, project_id, revision_id, chat_id, message, to_who)
  # messages are posted using normal HTM access, not XML
  chat = Chat.find(chat_id)
  chat_messages_num = chat.messages.count
  to_who_params = { 'max_idx' => to_who.length }
  to_who.each do |user|
    idx = 1
    to_who_params["for_who#{idx}"] = user.id
    idx += 1
  end

  post(url_for(controller: :chats, action: :create_message, project_id: project_id, revision_id: revision_id, id: chat_id),
       params: { session: session, body: message }.merge(to_who_params))
  assert_response :redirect
  chat.reload
  assert_equal chat_messages_num + 1, chat.messages.count

  assert_page_ok({ controller: :chats, action: :show, project_id: project_id, revision_id: revision_id, id: chat_id },
                 params: { session: session })
end

def dummy_revision_stats
  Marshal.dump('word_count' => { 'English' => { WORDS_STATUS[WORDS_STATUS_DONE] => 33,
                                                WORDS_STATUS[WORDS_STATUS_NEW] => 44 },
                                 'Spanish' => { WORDS_STATUS[WORDS_STATUS_MODIFIED] => 55,
                                                WORDS_STATUS[WORDS_STATUS_NEW] => 66 } },
               'sentence_count' => { 'English' => { WORDS_STATUS[WORDS_STATUS_DONE] => 12,
                                                    WORDS_STATUS[WORDS_STATUS_NEW] => 34 },
                                     'Spanish' => { WORDS_STATUS[WORDS_STATUS_MODIFIED] => 56,
                                                    WORDS_STATUS[WORDS_STATUS_NEW] => 78 } },
               'document_count' => { 'English' => { WORDS_STATUS[WORDS_STATUS_DONE] => 98,
                                                    WORDS_STATUS[WORDS_STATUS_NEW] => 87 },
                                     'Spanish' => { WORDS_STATUS[WORDS_STATUS_MODIFIED] => 76,
                                                    WORDS_STATUS[WORDS_STATUS_NEW] => 65 } })
end

def setup_full_project(user, proj_name, cms_request = nil)
  # ------------------------------ client project setup ----------------------------

  # log in as a client
  session = login(user)

  # create a project
  project_id = create_project(session, proj_name)
  project = Project.find(project_id)

  # create a new revision
  revision_id = create_revision(session, project_id, 'Created by test', true, cms_request)
  revision = Revision.find(revision_id)
  changenum = assert_track_changes(session, changenum, "Changenum didn't increment after revision was created")

  # ---------------- upload support files and a new version ------------------------
  support_file_id = create_support_file(session, project_id, 'sample/support_files/styles.css.gz')
  # create a project file that includes the correct support file ID
  f = File.open("#{File.expand_path(Rails.root)}/test/fixtures/sample/Initial/PB.xml", 'rb')
  txt = f.read
  txt = txt.gsub('$SUPPORT_FILE_ID', String(support_file_id))
  txt = txt.gsub('$REV_ID', String(revision_id))
  Zlib::GzipWriter.open("#{File.expand_path(Rails.root)}/test/fixtures/sample/Initial/produced.xml.gz") do |gz|
    gz.write(txt)
  end
  # upload this project file (upload version)
  version_id = create_version(session, project_id, revision_id, 'sample/Initial/produced.xml.gz')

  unless cms_request
    # update the revision's description
    description = 'Some very interesting story'
    post url_for(controller: :revisions, action: :edit_description, project_id: project_id, id: revision_id),
         params: { session: session, req: 'save', revision: { description: description } },
         xhr: true

    assert_response :success
    revision.reload
    assert_equal description, revision.description

    # update the revision's source language
    source_language = 1
    post url_for(controller: :revisions, action: :edit_source_language, project_id: project_id, id: revision_id),
         params: { session: session, req: 'save', revision: { language_id: source_language } },
         xhr: true
    assert_response :success

    project.reload
    revision.reload
    assert_equal(source_language, revision.language_id, 'Source language ID did not update')

    # setup the required revision details
    # revision conditions
    post url_for(controller: :revisions, action: :edit_conditions),
         params: {
           session: session, req: 'save', project_id: project_id, id: revision_id,
           revision: { max_bid: 0.1, max_bid_currency: 1, bidding_duration: DAYS_TO_BID, project_completion_duration: DAYS_TO_COMPLETE_WORK, word_count: 1 }
         },
         xhr: true

    assert_response :success

    # languages
    language_to_translate_to = [languages(:Spanish), languages(:German), languages(:French)]
    language_list = {}
    language_to_translate_to.each { |lang| language_list[lang.id] = 1 }
    # language_list = {languages(:Spanish).id=>1, languages(:German).id=>1, languages(:French).id=>1}
    post url_for(controller: :revisions, action: :edit_languages),
         params: { session: session, project_id: project_id, id: revision_id, req: 'save', language: language_list },
         xhr: true
    assert_response :success

    revision.reload
    language_to_translate_to.each do |lang|
      assert_not_equal 0, revision.lang_word_count(lang)
    end
  end

  logout(session)

  project
end

def translator_bid(xsession, chat, language, amount, bid_status = BID_GIVEN)
  # translator starts bid
  post url_for(controller: :chats, action: :edit_bid, project_id: chat.revision.project_id, revision_id: chat.revision_id, id: chat.id),
       params: { session: xsession, lang_id: language.id },
       xhr: true
  assert_response :success

  # translator saves the bid
  post url_for(controller: :chats, action: :save_bid, project_id: chat.revision.project_id, revision_id: chat.revision_id, id: chat.id),
       params: { session: xsession, bid: { amount: amount }, do_save: '1', lang_id: language.id },
       xhr: true
  assert_response :success

  assert_nil assigns(:warning)

  # find the revision language for this revision and language
  revision_language = RevisionLanguage.where('(revision_id=?) AND (language_id=?)', chat.revision_id, language.id).first
  bid = Bid.where('(chat_id=?) AND (revision_language_id=?)', chat.id, revision_language.id).first
  assert bid
  assert_equal bid_status, bid.status
  assert_equal amount, bid.amount

  # see that the chat page is still OK
  assert_page_ok({ controller: :chats, action: :show, project_id: chat.revision.project_id, revision_id: chat.revision_id, id: chat.id },
                 session: xsession)

  # see that the bid page is OK
  assert_page_ok({ controller: :bids, action: :show, project_id: chat.revision.project_id, revision_id: chat.revision_id, chat_id: chat.id, id: bid.id },
                 session: xsession)

  bid
end

def get_bids_chat(bids)
  chat = nil
  for bid in bids
    if !chat
      chat = bid.chat
    else
      assert_equal chat, bid.chat
    end
  end
  chat
end

def client_accepts_bids(session, bids, expected_bid_status)
  # --------------- client accepts bid -----------------
  chat = get_bids_chat(bids)

  # initialize the session variables
  get(url_for(controller: :chats, action: :show, project_id: chat.revision.project_id, revision_id: chat.revision_id, id: chat.id),
      params: { session: session })
  assert_response :success

  # select bid to accept
  for bid in bids
    post url_for(controller: :chats, action: :accept_bid, project_id: chat.revision.project_id, revision_id: chat.revision_id, id: chat.id),
         params: { session: session, do_save: '1', lang_id: bid.revision_language.language_id, bid_id: bid.id },
         xhr: true
    assert_response :success

    # accept the bid
    if bid.revision.client.money_accounts.first.balance >= bid.total_cost
      accept_list = {}
      ChatsController::BID_ACCEPT_CONDITIONS.size.times { |idx| accept_list[idx] = '1' }
      post url_for(controller: :chats, action: :transfer_bid_payment, project_id: chat.revision.project_id, revision_id: chat.revision_id, id: chat.id),
           params: { session: session, accept: accept_list, bid_id: bid.id },
           xhr: true
      assert_response :success
      assert_nil assigns(:warning)
    else
      assert bid.reload.status == BID_WAITING_FOR_PAYMENT
      get(project_revision_url(chat.revision.project, chat.revision),
          params: { session: session })
      assert :success
      assert_select '#payment_table', count: 1
    end
  end

  # see that the chat page is still OK
  assert_page_ok({ controller: :chats, action: :show, project_id: chat.revision.project_id, revision_id: chat.revision_id, id: chat.id },
                 params: { session: session })

  for bid in bids
    bid.reload
    assert_equal expected_bid_status, bid.status

    # see that the bid page is OK
    assert_page_ok({ controller: :bids, action: :show, project_id: chat.revision.project_id, revision_id: chat.revision_id, chat_id: chat.id, id: bid.id },
                   params: { session: session })
  end

end

def translator_completes_work(session, chat)
  versions_length = chat.revision.versions.length

  post(url_for(controller: :versions, action: :duplicate_complete, project_id: chat.revision.project.id, revision_id: chat.revision.id, id: chat.revision.versions[-1].id),
       params: { session: session })
  assert_response :redirect
  assert_equal 'New version auto-created', flash[:notice]

  chat.revision.reload
  assert_equal versions_length + 1, chat.revision.versions.length

  # translator indicates it's complete
  chat.bids.each do |bid|
    post url_for(controller: :chats, action: :declare_done, project_id: chat.revision.project_id, revision_id: chat.revision_id, id: chat.id),
         params: { lang_id: bid.revision_language.language_id, bid_id: bid.id, session: session },
         xhr: true
    assert_response :success
    bid.reload
    assert_equal BID_DECLARED_DONE, bid.status
  end
end

def client_finalizes_bids(session, bids)
  # --------------- client finalizes bid -----------------
  chat = get_bids_chat(bids)
  revision_id = chat.revision_id
  project_id = chat.revision.project_id

  # initialize the session variables
  get(url_for(controller: :chats, action: :show, project_id: project_id, revision_id: revision_id, id: chat.id),
      params: { session: session })
  assert_response :success

  # select bid to finalize
  for bid in bids
    post url_for(controller: :chats, action: :finalize_bid, project_id: project_id, revision_id: revision_id, id: chat.id),
         params: { session: session, bid_id: bid.id },
         xhr: true

    assert_response :success

    # try to finalize without accepting the conditions
    post url_for(controller: :chats, action: :finalize_bids, project_id: project_id, revision_id: revision_id, id: chat.id),
         params: { session: session, accept: {} },
         xhr: true

    assert_response :success
    assert assigns(:warning)

    # finalize selected bids
    accept_list = {}
    idx = 1
    ChatsController::BID_FINALIZE_CONDITIONS.each do
      accept_list[idx] = '1'
      idx += 1
    end
    post url_for(controller: :chats, action: :finalize_bids, project_id: project_id, revision_id: revision_id, id: chat.id),
         params: { session: session, accept: accept_list, bid_id: bid.id },
         xhr: true
    assert_response :success
    assert_nil assigns(:warning)
  end

  # see that the chat page is still OK
  assert_page_ok({ controller: :chats, action: :show, project_id: chat.revision.project_id, revision_id: chat.revision_id, id: chat.id },
                 params: { session: session })

  for bid in bids
    bid.reload
    assert_equal BID_COMPLETED, bid.status

    # see that the bid page is OK
    assert_page_ok({ controller: :bids, action: :show, project_id: chat.revision.project_id, revision_id: chat.revision_id, chat_id: chat.id, id: bid.id },
                   params: { session: session })
  end
end

def check_client_pages(client, session)
  assert_page_ok({ controller: :client, action: :index }, session: session)
  assert_page_ok({ controller: :client, action: :details }, { session: session }, false)
  assert_page_ok({ controller: :users, action: :show, id: client.id }, session: session)
  assert_page_ok({ controller: :bookmarks, action: :index }, session: session)
  assert_page_ok({ controller: :finance, action: :index }, session: session)
  assert_page_ok({ controller: :search, action: :index }, session: session)
  check_client_projects(client, session)
end

def check_client_projects(client, session)
  assert_page_ok({ controller: :projects, action: :index },
                 params: { session: session })
  client.projects.each do |project|
    project.support_files.each do |support_file|
      assert_page_ok({ controller: :support_files, action: :show, project_id: project.id, id: support_file.id },
                     params: { session: session })
    end

    project.revisions.each do |revision|
      assert_page_ok({ controller: :revisions, action: :show, project_id: project.id, id: revision.id },
                     params: { session: session })
      revision.chats.each do |chat|
        assert_page_ok({ controller: :chats, action: :show, project_id: project.id, revision_id: revision.id, id: chat.id },
                       params: { session: session })
      end
      revision.versions.each do |version|
        assert_page_ok({ controller: :versions, action: :show, project_id: project.id, revision_id: revision.id, id: version.id },
                       params: { session: session })
      end
    end
  end
end

def check_translator_pages(translator, session, check_versions = true)
  assert_page_ok({ controller: :translator, action: :index }, session: session)
  assert_page_ok({ controller: :translator, action: :details }, { session: session }, false)
  assert_page_ok({ controller: :users, action: :show, id: translator.id }, session: session)
  assert_page_ok({ controller: :bookmarks, action: :index }, session: session)
  assert_page_ok({ controller: :finance, action: :index }, session: session)
  assert_page_ok({ controller: :search, action: :index }, session: session)
  check_translator_projects(translator, session, check_versions)
end

def check_translator_projects(translator, session, check_versions)
  translator.chats.each do |chat|
    assert_page_ok({ controller: :chats, action: :show, project_id: chat.revision.project_id, revision_id: chat.revision_id, id: chat.id }, session: session)
    assert_page_ok({ controller: :revisions, action: :show, project_id: chat.revision.project_id, id: chat.revision_id }, session: session)
    next unless check_versions
    chat.revision.user_versions(translator).each do |version|
      assert_page_ok({ controller: :versions, action: :show, project_id: chat.revision.project_id, revision_id: chat.revision_id, id: version.id }, session: session)
    end
  end
end

def find_user_account(user, currency_id)
  # look for the translator account in that currency
  # puts "looking for account for user #{user.id} with currency #{currency_id}"
  account = UserAccount.where('currency_id = ? AND owner_id = ?', currency_id, user.id).first
end

def find_bid_account(bid, currency_id)
  # look for the translator account in that currency
  # puts "looking for account for user #{user.id} with currency #{currency_id}"
  account = BidAccount.where('currency_id = ? AND owner_id = ?', currency_id, bid.id).first
end

def get_account_balance(account)
  if account
    account.balance
  else
    0
  end
end

def assert_same_amount(a1, a2, details = nil)
  assert (a1 - a2).abs <= 0.03, details || "Expected: #{a1}, got: #{a2}"
end

def init_email_deliveries
  @emails_sent_count = ActionMailer::Base.deliveries.length
end

def check_emails_delivered(count)
  assert_equal @emails_sent_count + count, ActionMailer::Base.deliveries.length
  @emails_sent_count += count
end

def find_or_create_root_account(_foo = nil)
  root_account = RootAccount.where('currency_id=?', DEFAULT_CURRENCY_ID).first
  unless root_account
    root_account = RootAccount.create(currency_id: DEFAULT_CURRENCY_ID, balance: 0)
  end
  root_account
end

def save_html_page
  File.open('page.html', 'w') { |f| f.write response.body }
end

def assert_js_redirect
  assert_response :ok
  assert response.body.include?('location.href')
end
