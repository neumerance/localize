require "#{File.dirname(__FILE__)}/../test_helper"

class InviteTranslatorsForProjectTest < ActionDispatch::IntegrationTest
  fixtures :users, :translator_languages, :money_accounts, :languages, :currencies, :projects, :revisions, :chats, :identity_verifications, :private_translators

  # TODO: fix touch of produced.xml
  def test_assign_with_enough_balance
    client = users(:amir)

    init_email_deliveries

    project = setup_full_project(client, 'a private project')
    revision = project.revisions[0]
    assert !revision.revision_languages.empty?

    assert_equal 0, revision.released

    session = login(client)
    get(url_for(controller: :revisions, action: :show, project_id: project.id, id: revision.id))
    assert_response :success

    # show the available private translators
    # try without the revision language argument
    get(url_for(controller: :revisions, action: :invite_translator, project_id: project.id, id: revision.id))
    assert_response :redirect

    revision_language = revision.revision_languages[0]

    get(url_for(controller: :revisions, action: :invite_translator, project_id: project.id, id: revision.id, revision_language_id: revision_language.id))
    assert_response :success

    assert_equal 0, assigns(:release_problems).length
    assert assigns(:translators).length >= 1

    assert_equal 0, revision.chats.length

    translator = assigns(:translators)[0]
    post(url_for(controller: :chats, action: :create, revision_id: revision.id, project_id: project.id, translator_id: translator.id))
    assert_response :redirect

    revision.reload
    assert_equal 1, revision.chats.length

    check_emails_delivered(1)

    chat = revision.chats[0]
    post(url_for(controller: :chats, action: :create_message, revision_id: revision.id, project_id: project.id, id: chat.id),
         body: 'What I want to say', max_idx: 1, for_who1: translator.id)
    assert_response :redirect

    chat.reload
    assert_equal 2, chat.messages.length

    check_emails_delivered(1)

    logout(session)

    # log in as the translator, checks that he gets the project for translation
    session = login(translator)

    # place a bid on the project
    translator_bid(session, chat, revision_language.language, 0.09, bid_status = BID_GIVEN)
    check_emails_delivered(1)

    chat.reload
    assert_equal 1, chat.bids.length

    bid = chat.bids[0]

    logout(session)

    # --- client accepts bid
    session = login(client)
    client_accepts_bids(session, [bid], BID_ACCEPTED)
    check_emails_delivered(1)

    logout(session)

    # log in as the translator, checks that he gets the project for translation
    session = login(translator)

    # --------------- Translator downloads client version ----------
    get(url_for(controller: :versions, action: :show, project_id: project.id, revision_id: revision.id, id: revision.versions[0].id, format: 'xml'))
    assert_response :success

    # --------------- Translator uploads a version -----------------

    # translator does first upload
    trans_version_id = create_version(session, project.id, revision.id, 'sample/Initial/produced.xml.gz')
    # changenum = assert_track_changes(session, changenum, "Client changenum didn't increment after translator uploaded a version")
    revision.reload

    assert_equal 2, revision.versions.length
    check_emails_delivered(1)

    translator_completes_work(session, chat)
    check_emails_delivered(2)

    logout(session)

    # --------------- client finalizes bid -----------------
    # initialize the session variables
    session = login(client)

    get(url_for(controller: :chats, action: :show, project_id: project.id, revision_id: revision.id, id: chat.id))
    assert_response :success

    # select bids to finalize
    chat.bids.each do |b|
      xml_http_request(:post, url_for(controller: :chats, action: :finalize_bid, project_id: project.id, revision_id: revision.id, id: chat.id),
                       bid_id: b.id)
      assert_response :success
    end

    check_emails_delivered(0)

    # finalize selected bids
    accept_list = {}
    idx = 1
    ChatsController::BID_FINALIZE_CONDITIONS.each do
      accept_list[idx] = '1'
      idx += 1
    end
    xml_http_request(:post, url_for(controller: :chats, action: :finalize_bids, project_id: project.id, revision_id: revision.id, id: chat.id),
                     session: session,	accept: accept_list, bid_id: bid.id)
    assert_response :success
    assert_nil assigns(:warning)
    chat.bids.each do |b|
      b.reload
      assert_equal BID_COMPLETED, b.status
    end
    check_emails_delivered(1)

  end

end
