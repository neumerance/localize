require "#{File.dirname(__FILE__)}/../test_helper"

class AssignProjectToPrivateTranslators < ActionDispatch::IntegrationTest
  fixtures :users, :languages

  def test_assign_with_enough_balance
    client = users(:amir)
    run_project_assignment_test(client, 1000)
  end

  def run_project_assignment_test(client, starting_balance)

    init_email_deliveries

    project = setup_full_project(client, 'a private project')
    revision = project.revisions[0]
    assert !revision.revision_languages.empty?

    session = login(client)
    get(url_for(controller: :revisions, action: :show, project_id: project.id, id: revision.id))
    assert_response :success
    assert assigns(:can_assign_to_private_translators)

    # show the available private translators
    get(url_for(controller: :revisions, action: :select_private_translators,
                project_id: project.id, id: revision.id))
    assert_response :success
    assert assigns(:my_translators).length > 1

    # don't select any translator
    lang_param = {}
    revision.revision_languages.each { |rl| lang_param["translator_for#{rl.id}"] = 0 }
    post(url_for(controller: :revisions, action: :review_payment_for_private_translators,
                 project_id: project.id, id: revision.id),
         params: lang_param)
    assert_response :success
    assert_equal 0, assigns(:num_languages)

    # select a translator for all languages
    pt1 = users(:pt1)
    lang_param = {}
    revision.revision_languages.each { |rl| lang_param["translator_for#{rl.id}"] = pt1.id }
    post(url_for(controller: :revisions, action: :review_payment_for_private_translators,
                 project_id: project.id, id: revision.id),
         params: lang_param)
    assert_response :success
    assert_equal revision.revision_languages.length, assigns(:num_languages)

    total_cost = assigns(:total_cost)
    selected_translators = assigns(:selected_translators)
    assert total_cost

    # Private translation jobs should always be free (client does not pay,
    # translator does not get paid)
    assert_equal 0, total_cost

    # deposit the payment and start the work
    money_account = client.find_or_create_account(DEFAULT_CURRENCY_ID)
    money_account.update_attributes(balance: starting_balance)
    prev_balance = money_account.balance

    root_account = RootAccount.first
    unless root_account
      root_account = RootAccount.create!(currency_id: DEFAULT_CURRENCY_ID, balance: 0)
    end
    prev_root_balance = root_account.balance

    check_emails_delivered(0)

    post(url_for(controller: :revisions, action: :transfer_payment_for_translation,
                 project_id: project.id, id: revision.id, format: :js),
         params: lang_param.merge(selected_translators: selected_translators, total_cost: total_cost))
    assert_response :success

    logout(session)

    expected_gain = 0
    expected_gain = yield(total_cost) if block_given?

    money_account.reload
    root_account.reload
    assert_same_amount(prev_balance - total_cost + expected_gain, money_account.balance)
    assert_same_amount(prev_root_balance + total_cost, root_account.balance)

    # log in as the translator, checks that he gets the project for translation
    session = login(pt1)

    get(url_for(controller: :translator, action: :details, format: :xml))
    assert_response :success

    chats = assigns(:chats)
    assert_equal 1, chats.length
    chat = chats[0]

    assert_equal revision.revision_languages.length, chat.bids.length
    chat.bids.each do |bid|
      assert_equal BID_ACCEPTED, bid.status
      assert_equal 1, bid.won
      assert_equal 0, bid.amount
    end

    # --------------- Translator downloads client version ----------
    get(url_for(controller: :versions, action: :show, project_id: project.id,
                revision_id: revision.id, id: revision.versions[0].id, format: 'xml'))
    assert_response :success

    # --------------- Translator uploads a version -----------------

    post(url_for(controller: :versions, action: :duplicate_complete, project_id: project.id,
                 revision_id: revision.id, id: revision.versions[-1].id))
    assert_response :redirect

    revision.reload
    assert_equal 2, revision.versions.length
    check_emails_delivered(4)

    # translator indicates it's complete
    chat.bids.each do |bid|
      post(url_for(controller: :chats, action: :declare_done,
                   project_id: bid.chat.revision.project_id, revision_id: bid.chat.revision_id,
                   id: bid.chat.id),
           params: { lang_id: bid.revision_language.language_id, bid_id: bid.id },
           xhr: true)
      assert_response :success
      bid.reload
      assert_equal BID_DECLARED_DONE, bid.status

      check_emails_delivered(1)
    end

    logout(session)

    # --------------- client finalizes bid -----------------
    # initialize the session variables
    session = login(client)

    get(url_for(controller: :chats, action: :show, project_id: project.id, revision_id: revision.id, id: chat.id))
    assert_response :success

    # select bids to finalize
    chat.bids.each do |bid|
      post(url_for(controller: :chats, action: :finalize_bid, project_id: project.id,
                   revision_id: revision.id, id: chat.id),
           xhr: true, params: { bid_id: bid.id })
      assert_response :success

      # finalize selected bids
      accept_list = {}
      idx = 1
      ChatsController::BID_FINALIZE_CONDITIONS.each do
        accept_list[idx] = '1'
        idx += 1
      end
      post(url_for(controller: :chats, action: :finalize_bids, project_id: project.id,
                   revision_id: revision.id, id: chat.id),
           params: { session: session, accept: accept_list, bid_id: bid.id },
           xhr: true)
    end
    assert_response :success
    assert_nil assigns(:warning)
    chat.bids.each do |bid|
      bid.reload
      assert_equal BID_COMPLETED, bid.status
    end
    check_emails_delivered(revision.revision_languages.length)

  end

end
