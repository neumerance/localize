require "#{File.dirname(__FILE__)}/../test_helper"

class ArbitrationTest < ActionDispatch::IntegrationTest
  fixtures :users, :money_accounts, :languages, :currencies, :projects, :revisions, :chats, :identity_verifications

  def test_mutual_arbitration

    Project.destroy_all
    Arbitration.delete_all
    ArbitrationOffer.delete_all

    # log in as a client
    client = users(:amir)
    project = setup_full_project(client, 'Mutual arbitration project')
    revision = project.revisions[0]

    session = login(client)

    # release this revision
    post url_for(controller: :revisions, action: :edit_release_status, project_id: project.id, id: revision.id),
         params: { session: session, req: 'show' }, xhr: true
    assert_response :success
    assert_nil assigns(:warnings)

    # log in as a translator
    translator = users(:orit)
    xsession = login(translator)

    chat_id = create_chat(xsession, project.id, revision.id)
    chat = Chat.find(chat_id)

    language = languages(:Spanish)
    amount = MINIMUM_BID_AMOUNT
    bid = translator_bid(xsession, chat, language, amount)

    # accept the bid
    client_accepts_bids(session, [bid], BID_ACCEPTED)

    # ----------- put the bid into arbitration --------------

    init_email_deliveries

    # view the bid
    get(url_for(controller: :bids, action: :show, project_id: project.id, revision_id: revision.id,
                chat_id: chat.id, id: bid.id),
        params: { session: session })
    assert_response :success

    # request an arbitration
    get(url_for(controller: :arbitrations, action: :new),
        session: session, bid_id: bid.id, kind: 'bid')
    assert_response :success

    xml_http_request(:post, url_for(controller: :arbitrations, action: :request_cancel_bid),
                     params: { session: session })
    assert_response :success

    # submit, without entering the required data
    xml_http_request(:post, url_for(controller: :arbitrations, action: :create_cancel_bid_arbitration),
                     params: { session: session })
    assert_response :success
    assert assigns(:warning)

    # submit, with complete data
    reason = 'Fed up with this system.'
    xml_http_request(:post, url_for(controller: :arbitrations, action: :create_cancel_bid_arbitration),
                     params: { :session => session, 'how_to_handle' => 'self', 'reason' => reason })
    assert_response :success
    assert_nil assigns(:warning)

    check_emails_delivered(2)

    # find the created arbitration
    arbitration = Arbitration.first
    assert arbitration

    assert_equal arbitration.messages.length, 1
    message = arbitration.messages[-1]
    assert_equal message.body, reason

    # show the arbitration
    get(url_for(controller: :arbitrations, action: :show, id: arbitration.id), params: { session: session })
    assert_response :success

    # see that we can post messages
    assert_select 'table#reply'

    post(url_for(controller: :arbitrations, action: :create_message, id: arbitration.id),
         params: { session: session, body: "Here's my message" })
    assert_response :redirect
    arbitration.reload
    assert_equal arbitration.messages.length, 2

    check_emails_delivered(1)

    post(url_for(controller: :arbitrations, action: :create_message, id: arbitration.id),
         params: { session: xsession, body: "Here's my response too" })
    assert_response :redirect
    arbitration.reload
    assert_equal arbitration.messages.length, 3

    check_emails_delivered(1)

    # make an offer to finish the arbitration
    xml_http_request(:post, url_for(controller: :arbitrations, action: :edit_offer, id: arbitration.id),
                     params: { :session => session, 'req' => 'show' })
    assert_response :success

    # save the offer
    pay_amount = 10.0
    xml_http_request(:post, url_for(controller: :arbitrations, action: :edit_offer, id: arbitration.id),
                     params: { session: session, your_offer: { amount: pay_amount } })
    assert_response :success
    assert_equal 1, ArbitrationOffer.count

    check_emails_delivered(1)

    # show the arbitration
    get(url_for(controller: :arbitrations, action: :show, id: arbitration.id), params: { session: session })
    assert_response :success

    # delete that offer
    xml_http_request(:post, url_for(controller: :arbitrations, action: :edit_offer, id: arbitration.id),
                     params: { session: session, req: 'del' })
    assert_response :success
    assert_equal 0, ArbitrationOffer.count

    # show the arbitration
    get(url_for(controller: :arbitrations, action: :show, id: arbitration.id), params: { session: session })
    assert_response :success

    # make an offer to finish the arbitration
    xml_http_request(:post, url_for(controller: :arbitrations, action: :edit_offer, id: arbitration.id),
                     params: { :session => session, 'req' => 'show' })
    assert_response :success

    # save the offer
    xml_http_request(:post, url_for(controller: :arbitrations, action: :edit_offer, id: arbitration.id),
                     params: { session: session, your_offer: { amount: pay_amount } })
    assert_response :success
    assert_equal 1, ArbitrationOffer.count
    offer = ArbitrationOffer.first
    assert offer
    assert_equal OFFER_GIVEN, offer.status

    check_emails_delivered(1)

    # show the arbitration
    get(url_for(controller: :arbitrations, action: :show, id: arbitration.id), params: { session: session })
    assert_response :success

    # -------------- translator side ---------------
    bid_payment = bid.account.balance
    assert_not_equal 0, bid_payment

    # locate the translator and client account
    xlat_account = translator.money_accounts[0]
    client_account = client.money_accounts[0]
    prev_xlat_balance = if xlat_account
                          xlat_account.balance
                        else
                          0
                        end

    prev_client_balance = if client_account
                            client_account.balance
                          else
                            0
                          end

    root_account = find_or_create_root_account
    prev_root_balance = root_account.balance

    # view the arbitration as the translator
    get(url_for(controller: :arbitrations, action: :show, id: arbitration.id), params: { session: xsession })
    assert_response :success

    # accept the offer
    xml_http_request(:post, url_for(controller: :arbitrations, action: :accept_offer, id: arbitration.id),
                     params: { session: xsession })
    assert_response :success

    check_emails_delivered(1)
    # see that the payment had completed and refund made to the rest of the money
    client.reload
    translator.reload
    xlat_account = translator.money_accounts[0]
    client_account = client.money_accounts[0]
    client_account.reload
    root_account.reload
    offer.reload
    revision.reload
    arbitration.reload
    bid.reload

    assert_equal OFFER_ACCEPTED, offer.status
    assert_equal BID_TERMINATED, bid.status
    assert_equal ARBITRATION_CLOSED, arbitration.status

    assert_equal 0, bid.account.balance
    assert_same_amount(prev_xlat_balance + pay_amount * (1 - FEE_RATE), xlat_account.balance)
    assert_same_amount(prev_client_balance + (bid_payment - pay_amount), client_account.balance)
    assert_same_amount(prev_root_balance + pay_amount * FEE_RATE, root_account.balance)

    # see that both client and translators cannot post anymore
    get(url_for(controller: :arbitrations, action: :show, id: arbitration.id), params: { session: session })
    assert_response :success
    assert_select 'table#reply', false

    get(url_for(controller: :arbitrations, action: :show, id: arbitration.id), params: { session: xsession })
    assert_response :success
    assert_select 'table#reply', false

    post(url_for(controller: :arbitrations, action: :create_message, id: arbitration.id),
         params: { session: session, body: "This comment doesn't fly" })
    assert_response :redirect
    arbitration.reload
    assert_equal arbitration.messages.length, 3

    check_emails_delivered(0)
  end

  skip def test_supporter_arbitration

    Project.destroy_all
    Arbitration.delete_all
    ArbitrationOffer.delete_all

    # log in as a client
    client = users(:amir)
    project = setup_full_project(client, 'Supporter arbitration project')
    revision = project.revisions[0]

    session = login(client)

    # release this revision
    xml_http_request(:post, url_for(controller: :revisions, action: :edit_release_status,
                                    project_id: project.id, id: revision.id),
                     params: { session: session, req: 'show' })
    assert_response :success
    assert_nil assigns(:warnings)

    # log in as a translator
    translator = users(:orit)
    xsession = login(translator)

    chat_id = create_chat(xsession, project.id, revision.id)
    chat = Chat.find(chat_id)

    language = languages(:Spanish)
    amount = MINIMUM_BID_AMOUNT
    bid = translator_bid(xsession, chat, language, amount)

    # accept the bid
    client_accepts_bids(session, [bid], BID_ACCEPTED)

    # ----------- put the bid into arbitration --------------

    init_email_deliveries

    # view the bid
    get(url_for(controller: :bids, action: :show, project_id: project.id, revision_id: revision.id,
                chat_id: chat.id, id: bid.id),
        session: session)
    assert_response :success

    # request an arbitration
    get(url_for(controller: :arbitrations, action: :new),
        session: session, bid_id: bid.id, kind: 'bid')
    assert_response :success

    xml_http_request(:post, url_for(controller: :arbitrations, action: :request_cancel_bid),
                     params: { session: session })
    assert_response :success

    # submit, without entering the required data
    xml_http_request(:post, url_for(controller: :arbitrations, action: :create_cancel_bid_arbitration),
                     params: { session: session })
    assert_response :success
    assert assigns(:warning)

    # submit, with complete data
    reason = 'Fed up with this system. Please help!'
    xml_http_request(:post, url_for(controller: :arbitrations, action: :create_cancel_bid_arbitration),
                     params: { :session => session, 'how_to_handle' => 'supporter', 'reason' => reason })
    assert_response :success
    assert_nil assigns(:warning)

    check_emails_delivered(2)

    # find the created arbitration
    arbitration = Arbitration.first
    assert arbitration

    assert_equal arbitration.messages.length, 1
    message = arbitration.messages[-1]
    assert_equal message.body, reason

    # view the arbitration
    get(url_for(controller: :arbitrations, action: :show, id: arbitration.id), params: { session: session })
    assert_response :success

    # see that we can post messages
    assert_select 'table#reply'

    post(url_for(controller: :arbitrations, action: :create_message, id: arbitration.id),
         params: { session: session, body: "Here's my message" })
    assert_response :redirect
    arbitration.reload
    assert_equal arbitration.messages.length, 2

    check_emails_delivered(1)

    # view the arbitration
    get(url_for(controller: :arbitrations, action: :show, id: arbitration.id), session: session)
    assert_response :success

    post(url_for(controller: :arbitrations, action: :create_message, id: arbitration.id),
         params: { session: xsession, body: "Here's my response too" })
    assert_response :redirect
    arbitration.reload
    assert_equal arbitration.messages.length, 3

    check_emails_delivered(1)

    # view the arbitration
    get(url_for(controller: :arbitrations, action: :show, id: arbitration.id), params: { session: xsession })
    assert_response :success

    # log in as a supporter
    supporter = users(:supporter)
    ssession = login(supporter)

    get(url_for(controller: :arbitrations, action: :show, id: arbitration.id), params: { session: ssession })
    assert_response :success

    post(url_for(controller: :arbitrations, action: :assign_to_supporter,
                 id: arbitration.id, format: :js), session: ssession)
    assert_response :success
    arbitration.reload
    assert_equal arbitration.supporter_id, supporter.id

    # new comments will go to the supporter too
    post(url_for(controller: :arbitrations, action: :create_message, id: arbitration.id),
         params: { session: xsession, body: "Here's my response too" })
    assert_response :redirect
    arbitration.reload
    assert_equal arbitration.messages.length, 4

    check_emails_delivered(2)

    # -------------- translator side ---------------
    bid_payment = bid.account.balance
    assert_not_equal 0, bid_payment

    # locate the translator and client account
    xlat_account = translator.money_accounts[0]
    client_account = client.money_accounts[0]
    prev_xlat_balance = if xlat_account
                          xlat_account.balance
                        else
                          0
                        end

    prev_client_balance = if client_account
                            client_account.balance
                          else
                            0
                          end

    root_account = find_or_create_root_account
    prev_root_balance = root_account.balance

    # open the ruling dialog
    xml_http_request(:post, url_for(controller: :arbitrations, action: :edit_ruling, id: arbitration.id),
                     params: { :session => ssession, 'req' => 'show' })
    assert_response :success

    # save the ruling
    pay_amount = 15.0
    xml_http_request(:post, url_for(controller: :arbitrations, action: :edit_ruling, id: arbitration.id),
                     params: { session: ssession, ruling: { amount: pay_amount } })
    assert_response :success
    assert_equal 1, ArbitrationOffer.count

    offer = ArbitrationOffer.first
    assert offer
    assert_equal OFFER_ACCEPTED, offer.status

    check_emails_delivered(2)

    # see that the payment had completed and refund made to the rest of the money
    client.reload
    translator.reload
    xlat_account = translator.money_accounts[0]
    client_account = client.money_accounts[0]
    client_account.reload
    root_account.reload
    offer.reload
    revision.reload
    arbitration.reload
    bid.reload

    assert_equal OFFER_ACCEPTED, offer.status
    assert_equal BID_TERMINATED, bid.status
    assert_equal ARBITRATION_CLOSED, arbitration.status

    assert_equal 0, bid.account.balance
    assert_same_amount(prev_xlat_balance + pay_amount * (1 - FEE_RATE), xlat_account.balance)
    assert_same_amount(prev_client_balance + (bid_payment - pay_amount), client_account.balance)
    assert_same_amount(prev_root_balance + pay_amount * FEE_RATE, root_account.balance)

    # see that both client and translators cannot post anymore
    get(url_for(controller: :arbitrations, action: :show, id: arbitration.id), params: { session: session })
    assert_response :success
    assert_select 'table#reply', false

    get(url_for(controller: :arbitrations, action: :show, id: arbitration.id), params: { session: xsession })
    assert_response :success
    assert_select 'table#reply', false

    # view the arbitration by the supporter
    get(url_for(controller: :arbitrations, action: :show, id: arbitration.id), params: { session: ssession })
    assert_response :success

    check_client_pages(client, session)

    # TODO: fix check_translator_projects
    check_translator_pages(translator, xsession)

    check_emails_delivered(0)
  end

end
