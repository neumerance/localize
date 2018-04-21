require "#{File.dirname(__FILE__)}/../test_helper"

class ManualProjectTest < ActionDispatch::IntegrationTest
  fixtures :users, :languages, :currencies

  def test_user_create_project

    init_email_deliveries

    client = users(:amir)
    client_account = find_user_account(client, 1)
    client_balance = get_account_balance(client_account)

    session = login(client)

    name = 'hello project'

    current_projects = Project.count

    get(url_for(controller: :projects, action: :new))
    assert_response :success

    # create the projects
    post(url_for(controller: :projects, action: :create))
    assert_response :success
    assert_equal current_projects, Project.count

    # create the projects
    post(url_for(controller: :projects, action: :create), project: { name: name })
    assert_response :redirect
    assert_equal current_projects + 1, Project.count
    project = Project.all.to_a[-1]
    assert_equal MANUAL_PROJECT, project.kind

    assert_equal 1, project.revisions.count
    revision = project.revisions[-1]

    assert_equal MANUAL_PROJECT, revision.kind
    assert_nil revision.language_id
    assert_nil revision.description
    assert_equal 0, revision.revision_languages.length
    assert_equal 0, revision.chats.length
    assert_equal 0, revision.released

    get(url_for(controller: :revisions, action: :show, project_id: project.id, id: revision.id))
    assert_response :success
    assert assigns('canedit_source_language')

    # ----- setup the project -----
    # update the revision's description
    xml_http_request(:post, url_for(controller: :revisions, action: :edit_description, project_id: project.id, id: revision.id),
                     req: 'show')
    assert_response :success
    assert assigns('show_edit_description')

    description = 'Some very interesting story'
    xml_http_request(:post, url_for(controller: :revisions, action: :edit_description, project_id: project.id, id: revision.id),
                     req: 'save', revision: { description: description })
    assert_response :success
    revision.reload
    assert_equal description, revision.description

    # update the revision's source language
    xml_http_request(:post, url_for(controller: :revisions, action: :edit_source_language, project_id: project.id, id: revision.id),
                     req: 'show')
    assert_response :success
    assert assigns('show_edit_source_language')

    source_language = 1
    xml_http_request(:post, url_for(controller: :revisions, action: :edit_source_language, project_id: project.id, id: revision.id),
                     req: 'save', revision: { language_id: source_language })
    assert_response :success

    project.reload
    revision.reload
    assert_equal(source_language, revision.language_id, 'Source language ID did not update')

    # setup the required revision details
    # revision conditions
    xml_http_request(:post, url_for(controller: :revisions, action: :edit_conditions),
                     req: 'save', project_id: project.id, id: revision.id,
                     revision: { max_bid: 100, max_bid_currency: 1, bidding_duration: DAYS_TO_BID, project_completion_duration: DAYS_TO_COMPLETE_WORK, word_count: 1 })
    assert_response :success

    # languages
    language_list = { languages(:Spanish).id => 1, languages(:German).id => 1, languages(:French).id => 1 }
    xml_http_request(:post, url_for(controller: :revisions, action: :edit_languages),
                     project_id: project.id, id: revision.id, req: 'save',
                     language: language_list)
    assert_response :success

    # upload the file
    fdata = fixture_file_upload('sample/Initial/produced.xml.gz', 'application/octet-stream')
    multipart_post url_for(controller: :versions, action: :create, project_id: project.id, revision_id: revision.id),
                   session: session, version: { 'uploaded_data' => fdata }
    assert_response :redirect
    assert_equal 1, revision.reload.versions.size

    # release this revision
    xml_http_request(:post, url_for(controller: :revisions, action: :edit_release_status),
                     project_id: project.id, id: revision.id, req: 'show')
    assert_response :success
    assert_nil assigns(:warnings)
    revision.reload
    assert_equal 1, revision.released

    # Disable reviews
    revision.revision_languages.each do |rl|
      post disable_managed_work_url(rl.managed_work, format: :js)
      assert_response :success
      assert !rl.managed_work.reload.enabled?
    end

    current_logout

    translator = users(:orit)
    translator_account = find_user_account(translator, 1)
    translator_balance = get_account_balance(translator_account)
    xsession = login(translator)

    bids = []
    # create a chat in this revision
    chat_id = create_chat(xsession, project.id, revision.id)
    chat = Chat.find(chat_id)

    amount = 70
    for language in revision.languages
      bids << translator_bid(xsession, chat, language, amount)
    end

    logout(xsession)

    session = login(client)

    # ------- accept all bids ---------

    bids.each { |b| assert_nil b.account }
    client_accepts_bids(session, bids, BID_ACCEPTED)
    bids.each { |b| assert_equal amount, b.account.balance }

    check_emails_delivered(bids.length * 2)
    full_amount = amount * bids.length

    client_account.reload
    assert_same_amount(client_balance - full_amount, client_account.balance)

    # ------- client adds a message without an attachment to the chat -------
    get(url_for(controller: :chats, action: :show, project_id: project.id, revision_id: revision.id, id: chat_id))
    assert_response :success

    msg_count = chat.messages.count
    create_message(session, project.id, revision.id, chat_id, 'This is my message', [translator])

    chat.reload

    assert_equal msg_count + 1, chat.messages.count
    check_emails_delivered(1)

    message = chat.messages[-1]
    assert_equal 0, message.attachments.length

    # ------- client adds a message with an attachment to the chat -------
    get(url_for(controller: :chats, action: :show, project_id: project.id, revision_id: revision.id, id: chat_id))
    assert_response :success

    msg_count = chat.messages.count

    fname1 = 'sample/support_files/styles.css'
    fdata1 = fixture_file_upload(fname1, 'application/octet-stream')
    fname2 = 'sample/support_files/styles.css.gz'
    fdata2 = fixture_file_upload(fname2, 'application/octet-stream')
    multipart_post(url_for(controller: :chats, action: :create_message, project_id: project.id, revision_id: revision.id, id: chat_id),
                   body: 'This is my other message', file1: { 'uploaded_data' => fdata1 }, file2: { 'uploaded_data' => fdata2 },
                   max_idx: 1, for_who1: translator.id)
    assert_response :redirect

    chat.reload

    assert_equal msg_count + 1, chat.messages.count
    check_emails_delivered(1)

    message = chat.messages[-1]
    assert_equal 2, message.attachments.length

    logout(session)

    # --- translator declares the work as complete ---
    xsession = login(translator)

    bids.each do |bid|
      xml_http_request(:post, url_for(controller: :chats, action: :declare_done, project_id: bid.chat.revision.project_id, revision_id: bid.chat.revision_id, id: bid.chat.id),
                       lang_id: bid.revision_language.language_id, bid_id: bid.id)
      assert_response :success
      bid.reload
      assert_equal BID_DECLARED_DONE, bid.status

      check_emails_delivered(1)

      # make sure the translator can still see the chat without an error
      get(url_for(controller: :chats, action: :show, project_id: project.id, revision_id: revision.id, id: chat_id))
      assert_response :success

    end

    logout(xsession)

    session = login(client)

    # --------------- client finalizes bid -----------------
    # initialize the session variables
    get(url_for(controller: :chats, action: :show, project_id: project.id, revision_id: revision.id, id: chat_id))
    assert_response :success

    # find the root account, where the fee is going to
    root_account = RootAccount.where('currency_id=?', DEFAULT_CURRENCY_ID).first
    root_balance = get_account_balance(root_account)

    bids.each do |bid|
      # select bid to finalize
      xml_http_request(:post, url_for(controller: :chats, action: :finalize_bid, project_id: project.id, revision_id: revision.id, id: chat_id),
                       bid_id: bid.id)
      assert_response :success

      # try to finalize without accepting the conditions
      xml_http_request(:post, url_for(controller: :chats, action: :finalize_bids, project_id: project.id, revision_id: revision.id, id: chat_id),
                       accept: {}, bid_id: bid.id)
      assert_response :success
      assert assigns(:warning)

      # finalize selected bids
      accept_list = {}
      idx = 1
      ChatsController::BID_FINALIZE_CONDITIONS.each do
        accept_list[idx] = '1'
        idx += 1
      end
      xml_http_request(:post, url_for(controller: :chats, action: :finalize_bids, project_id: project.id, revision_id: revision.id, id: chat_id),
                       accept: accept_list, bid_id: bid.id)
      assert_response :success
      assert_nil assigns(:warning)
      bid.reload
      assert_equal BID_COMPLETED, bid.status
      check_emails_delivered(1)

      bid_account = bid_account = bid.account
      client_account.reload

      assert_equal 0, bid_account.balance
    end

    # check that the translator got credited
    if translator_account
      translator_account.reload
    else
      translator_account = find_user_account(translator, 1)
    end
    assert translator_account
    assert_same_amount(translator_account.balance, amount * bids.length * (1 - FEE_RATE))

    # check that the escrow amount when to the translator, was deducted from the client and the bid account is empty
    if root_account
      root_account.reload
    else
      root_account = RootAccount.where('currency_id=?', DEFAULT_CURRENCY_ID).first
      assert root_account
    end
    assert_same_amount(root_account.balance, amount * bids.length * FEE_RATE)

  end

  def test_with_review

    init_email_deliveries

    client = users(:amir)
    client_account = find_user_account(client, 1)
    client_balance = get_account_balance(client_account)

    session = login(client)

    name = 'hello project'

    current_projects = Project.count

    get(url_for(controller: :projects, action: :new))
    assert_response :success

    # create the projects
    post(url_for(controller: :projects, action: :create), project: { name: name })
    assert_response :redirect
    assert_equal current_projects + 1, Project.count
    project = Project.all.to_a[-1]
    assert_equal MANUAL_PROJECT, project.kind

    assert_equal 1, project.revisions.count
    revision = project.revisions[-1]

    assert_equal MANUAL_PROJECT, revision.kind
    assert_nil revision.language_id
    assert_nil revision.description
    assert_equal 0, revision.revision_languages.length
    assert_equal 0, revision.chats.length
    assert_equal 0, revision.released

    get(url_for(controller: :revisions, action: :show, project_id: project.id, id: revision.id))
    assert_response :success
    assert assigns('canedit_source_language')

    # ----- setup the project -----
    # update the revision's description
    xml_http_request(:post, url_for(controller: :revisions, action: :edit_description, project_id: project.id, id: revision.id),
                     req: 'show')
    assert_response :success
    assert assigns('show_edit_description')

    description = 'Some very interesting story'
    xml_http_request(:post, url_for(controller: :revisions, action: :edit_description, project_id: project.id, id: revision.id),
                     req: 'save', revision: { description: description })
    assert_response :success
    revision.reload
    assert_equal description, revision.description

    # update the revision's source language
    xml_http_request(:post, url_for(controller: :revisions, action: :edit_source_language, project_id: project.id, id: revision.id),
                     req: 'show')
    assert_response :success
    assert assigns('show_edit_source_language')

    source_language = 1
    xml_http_request(:post, url_for(controller: :revisions, action: :edit_source_language, project_id: project.id, id: revision.id),
                     req: 'save', revision: { language_id: source_language })
    assert_response :success

    project.reload
    revision.reload
    assert_equal(source_language, revision.language_id, 'Source language ID did not update')

    # setup the required revision details
    # revision conditions
    xml_http_request(:post, url_for(controller: :revisions, action: :edit_conditions),
                     req: 'save', project_id: project.id, id: revision.id,
                     revision: { max_bid: 100, max_bid_currency: 1, bidding_duration: DAYS_TO_BID, project_completion_duration: DAYS_TO_COMPLETE_WORK, word_count: 1 })
    assert_response :success

    # languages
    language_list = { languages(:Spanish).id => 1, languages(:German).id => 1, languages(:French).id => 1 }
    xml_http_request(:post, url_for(controller: :revisions, action: :edit_languages),
                     project_id: project.id, id: revision.id, req: 'save',
                     language: language_list)
    assert_response :success

    # upload the file
    fdata = fixture_file_upload('sample/Initial/produced.xml.gz', 'application/octet-stream')
    multipart_post url_for(controller: :versions, action: :create, project_id: project.id, revision_id: revision.id),
                   session: session, version: { 'uploaded_data' => fdata }
    assert_response :redirect
    assert_equal 1, revision.reload.versions.size

    # release this revision
    xml_http_request(:post, url_for(controller: :revisions, action: :edit_release_status),
                     project_id: project.id, id: revision.id, req: 'show')
    assert_response :success
    assert_nil assigns(:warnings)
    revision.reload
    assert_equal 1, revision.released

    current_logout

    reviewer = users(:guy)
    revision.revision_languages.each do |revision_language|
      managed_work = revision_language.managed_work
      managed_work.translator = reviewer
      managed_work.active = MANAGED_WORK_PENDING_PAYMENT
      assert managed_work.save
    end

    translator = users(:orit)
    translator_account = find_user_account(translator, 1)
    translator_balance = get_account_balance(translator_account)
    xsession = login(translator)

    bids = []
    # create a chat in this revision
    chat_id = create_chat(xsession, project.id, revision.id)
    chat = Chat.find(chat_id)

    amount = 70
    for language in revision.languages
      bids << translator_bid(xsession, chat, language, amount)
    end

    logout(xsession)

    session = login(client)

    # ------- accept all bids ---------
    client_accepts_bids(session, bids, BID_ACCEPTED)
    check_emails_delivered(bids.length * 2)

    full_amount = amount * bids.length * 1.5 # this includes the review cost (50%)

    client_account.reload
    assert_same_amount(client_balance - full_amount, client_account.balance)

    # ------- client adds a message without an attachment to the chat -------
    get(url_for(controller: :chats, action: :show, project_id: project.id, revision_id: revision.id, id: chat_id))
    assert_response :success

    msg_count = chat.messages.count
    post(url_for(controller: :chats, action: :create_message, project_id: project.id, revision_id: revision.id, id: chat_id),
         body: 'This is my message', max_idx: 1, for_who1: translator.id)
    assert_response :redirect

    chat.reload

    assert_equal msg_count + 1, chat.messages.count
    check_emails_delivered(1)

    message = chat.messages[-1]
    assert_equal 0, message.attachments.length

    # ------- client adds a message with an attachment to the chat -------
    get(url_for(controller: :chats, action: :show, project_id: project.id, revision_id: revision.id, id: chat_id))
    assert_response :success

    msg_count = chat.messages.count

    fname1 = 'sample/support_files/styles.css'
    fdata1 = fixture_file_upload(fname1, 'application/octet-stream')
    fname2 = 'sample/support_files/styles.css.gz'
    fdata2 = fixture_file_upload(fname2, 'application/octet-stream')
    multipart_post(url_for(controller: :chats, action: :create_message, project_id: project.id, revision_id: revision.id, id: chat_id),
                   body: 'This is my other message', file1: { 'uploaded_data' => fdata1 }, file2: { 'uploaded_data' => fdata2 },
                   max_idx: 1, for_who1: translator.id)
    assert_response :redirect

    chat.reload

    assert_equal msg_count + 1, chat.messages.count
    check_emails_delivered(1)

    message = chat.messages[-1]
    assert_equal 2, message.attachments.length

    logout(session)

    # --- translator declares the work as complete ---
    xsession = login(translator)

    bids.each do |bid|
      xml_http_request(:post, url_for(controller: :chats, action: :declare_done, project_id: bid.chat.revision.project_id, revision_id: bid.chat.revision_id, id: bid.chat.id),
                       lang_id: bid.revision_language.language_id, bid_id: bid.id)
      assert_response :success
      bid.reload
      assert_equal BID_DECLARED_DONE, bid.status

      check_emails_delivered(2) # one email to the client and another to the reviewer

      # make sure the translator can still see the chat without an error
      get(url_for(controller: :chats, action: :show, project_id: project.id, revision_id: revision.id, id: chat_id))
      assert_response :success

    end

    logout(xsession)

    revision.revision_languages.each do |revision_language|
      managed_work = revision_language.managed_work
      managed_work.reload
      assert_equal MANAGED_WORK_REVIEWING, managed_work.translation_status
    end

    # ---- reviewer completes the review ----

    session = login(reviewer)

    money_account = reviewer.find_or_create_account(DEFAULT_CURRENCY_ID)
    reviewer_balance = money_account.balance

    # check that the reviewer can access
    get(url_for(controller: :chats, action: :show, project_id: project.id, revision_id: revision.id, id: chat_id))
    assert_response :success

    assert assigns('is_reviewer')

    # now, indicate that the review is complete
    bids.each do |bid|
      xml_http_request(:post, url_for(controller: :chats, action: :review_complete, project_id: project.id, revision_id: revision.id, id: chat_id, bid_id: bid.id))
      assert_response :success

      check_emails_delivered(0)

      # finalize selected bids
      accept_list = {}
      idx = 1
      ChatsController::BID_REVIEW_CONDITIONS.each do
        accept_list[idx] = '1'
        idx += 1
      end
      assert_no_difference('bid.account.balance') do
        xml_http_request(:post, url_for(controller: :chats, action: :finalize_review, project_id: project.id, revision_id: revision.id, id: chat_id),
                         accept: accept_list, bid_id: bid.id)
        assert_response :success
        assert_nil assigns(:warning)
      end

      check_emails_delivered(1)
    end

    revision.revision_languages.each do |revision_language|
      managed_work = revision_language.managed_work
      managed_work.reload
      assert_equal MANAGED_WORK_WAITING_FOR_PAYMENT, managed_work.translation_status
    end

    logout(session)

    # --------------- client finalizes bid -----------------
    session = login(client)

    # initialize the session variables
    get(url_for(controller: :chats, action: :show, project_id: project.id, revision_id: revision.id, id: chat_id))
    assert_response :success

    # find the root account, where the fee is going to
    root_account = RootAccount.where('currency_id=?', DEFAULT_CURRENCY_ID).first
    root_balance = get_account_balance(root_account)

    bids.each do |bid|
      # select bid to finalize
      xml_http_request(:post, url_for(controller: :chats, action: :finalize_bid, project_id: project.id, revision_id: revision.id, id: chat_id),
                       bid_id: bid.id)
      assert_response :success

      # try to finalize without accepting the conditions
      xml_http_request(:post, url_for(controller: :chats, action: :finalize_bids, project_id: project.id, revision_id: revision.id, id: chat_id),
                       accept: {}, bid_id: bid.id)
      assert_response :success
      assert assigns(:warning)

      # finalize selected bids
      accept_list = {}
      idx = 1
      ChatsController::BID_FINALIZE_CONDITIONS.each do
        accept_list[idx] = '1'
        idx += 1
      end
      xml_http_request(:post, url_for(controller: :chats, action: :finalize_bids, project_id: project.id, revision_id: revision.id, id: chat_id),
                       accept: accept_list, bid_id: bid.id)
      assert_response :success
      assert_nil assigns(:warning)
      bid.reload
      assert_equal BID_COMPLETED, bid.status
      check_emails_delivered(1)

      bid_account = bid.account
      client_account.reload

      assert_same_amount(0, bid_account.balance)
    end

    # check that the translator got credited
    if translator_account
      translator_account.reload
    else
      translator_account = find_user_account(translator, 1)
    end
    assert translator_account
    assert_same_amount(translator_account.balance, amount * bids.length * (1 - FEE_RATE))

    # check that the reviewer got credited
    reviewer.money_account.reload
    assert_same_amount(reviewer.money_account.balance, reviewer_balance + (amount * bids.length * 0.5 * (1 - FEE_RATE)))

    # check that the escrow amount when to the translator, was deducted from the client and the bid account is empty
    if root_account
      root_account.reload
    else
      root_account = RootAccount.where('currency_id=?', DEFAULT_CURRENCY_ID).first
      assert root_account
    end
    assert_same_amount(root_account.balance, 1.5 * amount * bids.length * FEE_RATE)
  end

end
