require "#{File.dirname(__FILE__)}/../test_helper"

class PaymentTest < ActionDispatch::IntegrationTest
  fixtures :users, :languages

  skip def test_payment_for_bid

    @tx_sn = 0

    Project.destroy_all
    Invoice.destroy_all
    MoneyTransaction.destroy_all
    AccountLine.destroy_all
    PaypalMockReply.destroy_all
    Lock.destroy_all

    client = users(:amir)

    # clear the balance from the client's accounts, so that he needs to deposit
    MoneyAccount.all.each do |money_account|
      money_account.balance = 0
      money_account.save!
    end

    init_money_checker

    [true, false].each do |do_ipn|
      run_bid_payment_test(client, Faker::App.name, do_ipn)
    end

    [true, false].each do |do_ipn|
      # client = users(:amir)
      run_self_deposit_test(do_ipn, client, true)
    end

    # make sure nothing remained locked at the end
    assert_equal 0, Lock.count
  end

  skip def test_payment_for_bid_and_review

    @tx_sn = 0

    Project.destroy_all
    Invoice.destroy_all
    MoneyTransaction.destroy_all
    AccountLine.destroy_all
    PaypalMockReply.destroy_all
    Lock.destroy_all

    client = users(:amir)

    # clear the balance from the client's accounts, so that he needs to deposit
    client.money_accounts.each do |money_account|
      money_account.balance = 0
      money_account.save!
    end

    init_money_checker

    bid = nil
    [true, false].each do |do_ipn|
      bid = run_bid_payment_test(client, Faker::App.name, do_ipn)
    end

    chat = bid.chat
    revision = chat.revision
    project = revision.project

    managed_work = bid.revision_language.managed_work
    assert managed_work
    assert_equal MANAGED_WORK_ACTIVE, managed_work.active

    session = login(client)

    invoice_count = Invoice.count

    get(url_for(controller: :chats, action: :show, project_id: project.id, revision_id: revision.id, id: chat.id))
    assert_response :success
  end

  skip def test_payment_for_bid_with_used_account

    @tx_sn = 0

    Project.destroy_all
    Invoice.destroy_all
    MoneyTransaction.destroy_all
    AccountLine.destroy_all
    PaypalMockReply.destroy_all
    Lock.destroy_all
    ExternalAccount.destroy_all

    client = users(:amir)
    other_client = users(:doron)

    # puts "\nbefore"
    # puts "external account for client: #{client.external_accounts.length}"
    # puts "external account for other_client: #{other_client.external_accounts.length}"

    external_account = ExternalAccount.new(external_account_type: EXTERNAL_ACCOUNT_PAYPAL,
                                           status: 'verified',
                                           identifier: client.email,
                                           verified: 0)
    external_account.normal_user = other_client
    external_account.save!

    client.reload
    other_client.reload

    # puts "\nafter account setup"
    # puts "external account for client: #{client.external_accounts.length}"
    # puts "external account for other_client: #{other_client.external_accounts.length}"

    # clear the balance from the client's accounts, so that he needs to deposit
    client.money_accounts.each do |money_account|
      money_account.balance = 0
      money_account.save!
    end

    init_money_checker

    [true, false].each do |do_ipn|
      run_bid_payment_test(client, Faker::App.name, do_ipn)
    end

    [true, false].each do |do_ipn|
      # client = users(:amir)
      run_self_deposit_test(do_ipn, client, true)
    end

    # make sure nothing remained locked at the end
    assert_equal 0, Lock.count

    client.reload
    other_client.reload

    # puts "\nend of test"

    assert_equal 6, client.money_accounts[0].account_lines.length
    assert_equal 0, other_client.money_accounts[0].account_lines.length

    # puts "account lines in client account: #{client.money_accounts[0].account_lines.length}"
    # client.money_accounts[0].account_lines.each do |al|
    #	mt = al.money_transaction
    #	puts "#{mt.operation_code}: from_account - #{mt.source_account}, target_account - #{mt.target_account}"
    # end
    # puts "external account for client: #{client.external_accounts.length} - #{(client.external_accounts.collect { |ea| "#{ea.id}:#{ea.identifier}"}).join(', ')}"

    # puts "account lines in other_client account: #{other_client.money_accounts[0].account_lines.length}"
    # puts "external account for other_client: #{other_client.external_accounts.length} - #{(other_client.external_accounts.collect { |ea| "#{ea.id}:#{ea.identifier}"}).join(', ')}"

    session = login(client)
    get url_for(controller: :finance, action: :index), params: { session: session }
    assert_response :success
    logout(session)

    session = login(other_client)
    get url_for(controller: :finance, action: :index), params: { session: session }
    assert_response :success
    logout(session)
  end

  skip def test_payment_for_bid_with_affiliate

    @tx_sn = 0

    Project.destroy_all
    Invoice.destroy_all
    MoneyTransaction.destroy_all
    AccountLine.destroy_all
    PaypalMockReply.destroy_all
    Lock.destroy_all

    root_account = RootAccount.first

    idx = 1
    clients = {}

    [users(:amir), users(:shark)].each do |affiliate|

      indx = idx.to_s
      client = Client.create(fname: 'some', lname: 'guy', email: 'someguy' + indx + '@hello.com', password: '123',
                             nickname: 'someguy' + indx, affiliate_id: affiliate.id, userstatus: USER_STATUS_REGISTERED)

      # clear the balance from the client's accounts, so that he needs to deposit
      client.money_accounts.each do |money_account|
        money_account.balance = 0
        money_account.save!
      end

      clients[affiliate] = client

      idx += 1

    end

    init_money_checker

    [users(:amir), users(:shark)].each do |affiliate|

      client = clients[affiliate]

      affiliate_account = affiliate.find_or_create_account(DEFAULT_CURRENCY_ID)
      prev_affiliate_balance = affiliate_account.balance
      # puts "before, affiliate account balance: #{affiliate_account.balance}"

      prev_root_balance = if root_account
                            root_account.balance
                          else
                            0
                          end

      [true, false].each do |do_ipn|
        run_bid_payment_test(client, Faker::App.name, do_ipn)
      end

      [true, false].each do |do_ipn|
        # client = users(:amir)
        run_self_deposit_test(do_ipn, client, true)
      end

      # make sure nothing remained locked at the end
      assert_equal 0, Lock.count

      # affiliate_account = affiliate.find_or_create_account(DEFAULT_CURRENCY_ID)
      # assert affiliate_account
      if root_account
        root_account.reload
      else
        root_account = RootAccount.first
      end

      affiliate_account.reload

      # puts "after, affiliate account balance: #{affiliate_account.balance}"

      root_earning = root_account.balance - prev_root_balance
      assert root_earning > 0
      # puts "root_earning: #{root_earning}"

      expected_affiliate_earn = (root_earning / (1 - AFFILIATE_COMMISSION_RATE)) * AFFILIATE_COMMISSION_RATE

      assert_same_amount(expected_affiliate_earn, affiliate_account.balance - prev_affiliate_balance)

    end

  end

  def dont_test_verification
    @tx_sn = 0
    init_money_checker
    client = users(:doron)
    assert_equal false, client.verified?

    # see that any change in user details prevents the verification
    tx = PaypalMockReply.new(payer_email: client.email + 'x',
                             first_name: client.fname,
                             last_name: client.lname)
    run_self_deposit_test(true, client, false, tx)
    assert_equal false, client.verified?

    tx = PaypalMockReply.new(payer_email: client.email,
                             first_name: client.fname + 'x',
                             last_name: client.lname)
    run_self_deposit_test(true, client, false, tx)
    assert_equal false, client.verified?

    tx = PaypalMockReply.new(payer_email: client.email,
                             first_name: client.fname,
                             last_name: client.lname + 'x')
    run_self_deposit_test(true, client, false, tx)
    assert_equal false, client.verified?

    # with correct user details, verification passes OK
    run_self_deposit_test(true, client, false)
    assert_equal true, client.verified?
  end

  def test_admin_deposit_and_withdrawal
    @tx_sn = 0
    init_money_checker

    admin = users(:admin)
    client = users(:doron)

    session = login(admin)

    account = client.money_accounts[0]
    balance_before = account.balance

    # got to the account history
    get url_for(controller: :finance, action: :account_history, id: account.id), params: { session: session }
    assert_response :success

    get url_for(controller: :finance, action: :new_manual_invoice, id: account.id), params: { session: session, invtype: 'deposit' }
    assert_response :success
    assert_equal account, assigns['account']
    assert_equal 0, assigns['default_transfer_type']

    get url_for(controller: :finance, action: :new_manual_invoice, id: account.id), params: { session: session, invtype: 'withdraw' }
    assert_response :success
    assert_equal account, assigns['account']
    assert_equal 1, assigns['default_transfer_type']

    amount = 10.74
    # try a few calls, every time with missing arguments
    all_args = { 'transfer_type' => 0, 'account_type' => ExternalAccount::NAME.keys[-1], 'amount' => amount }
    post_args = {}
    all_args.each do |k, v|
      # add another argument
      post_args[k] = v

      post url_for(controller: :finance, action: :create_manual_invoice, id: account.id), params: { session: session }.merge(post_args)
      assert_response :success
      if post_args.keys.length == all_args.keys.length # should work without txid
        assert_nil assigns['warnings']
        assert assigns['invoice']

        account.reload
        assert_same_amount(balance_before + amount, account.balance)
        balance_before += amount

      else
        assert assigns['warnings'], post_args.inspect
        assert_nil assigns['invoice']
      end
    end

    # also should work with txid
    post_args = { 'transfer_type' => 0, 'account_type' => ExternalAccount::NAME.keys[-1], 'txid' => 'TESTTX', 'amount' => amount }
    post url_for(controller: :finance, action: :create_manual_invoice, id: account.id), params: { session: session }.merge(post_args)
    assert_response :success
    assert_nil assigns['warnings']
    assert assigns['invoice']
    account.reload
    assert_same_amount(balance_before + amount, account.balance)
    balance_before += amount

    2.times do
      add_deposit(amount)
      add_real_money(amount)
    end
    summary_money_check

    # now, try to withdraw more than we have
    all_args = { 'transfer_type' => 1, 'account_type' => ExternalAccount::NAME.keys[-1], 'txid' => 'TESTTX', 'amount' => account.balance + 0.1 }
    post url_for(controller: :finance, action: :create_manual_invoice, id: account.id), params: { session: session }.merge(all_args)
    assert_response :success
    assert assigns['warnings']
    assert_nil assigns['invoice']

    #  withdraw an amount that exists in the account
    amount = account.balance / 2
    all_args = { 'transfer_type' => 1, 'account_type' => ExternalAccount::NAME.keys[-1], 'txid' => 'TESTTX', 'amount' => amount }
    post url_for(controller: :finance, action: :create_manual_invoice, id: account.id), params: { session: session }.merge(all_args)
    assert_response :success
    assert_nil assigns['warnings']
    assert assigns['invoice']

    account.reload
    assert_same_amount(balance_before - amount, account.balance)
    balance_before -= amount

    add_deposit(-amount)
    add_real_money(-amount)
    summary_money_check

    #  clean up the account
    amount = account.balance
    all_args = { 'transfer_type' => 1, 'account_type' => ExternalAccount::NAME.keys[-1], 'txid' => 'TESTTX', 'amount' => amount }
    post url_for(controller: :finance, action: :create_manual_invoice, id: account.id), params: { session: session }.merge(all_args)
    assert_response :success
    assert_nil assigns['warnings']
    assert assigns['invoice']

    account.reload
    assert_same_amount(0, account.balance)
    balance_before -= amount

    add_deposit(-amount)
    add_real_money(-amount)
    summary_money_check
  end

  def run_self_deposit_test(do_ipn, client, do_coherency_tests, alternate_tx = nil)
    session = login(client)

    post url_for(controller: :finance, action: :index), params: { session: session }
    assert_response :success

    orig_number_of_invoices = client.invoices.count

    account = client.money_accounts[0]

    balance_before = account.balance

    # show the deposit box
    post url_for(controller: :finance, action: :make_deposit, id: account.id),
         params: { session: session, req: 'show' },
         xhr: true

    assert_response :success
    assert_nil assigns['warning']
    assert_equal orig_number_of_invoices, client.invoices.count

    # try to make a deposit, don't put in the amount
    post url_for(controller: :finance, action: :make_deposit, id: account.id),
         params: { session: session },
         xhr: true

    assert_response :success
    assert assigns['warning']
    assert_equal orig_number_of_invoices, client.invoices.count

    amount = 12.0

    # start a deposit with an amount
    post url_for(controller: :finance, action: :make_deposit, id: account.id),
         params: { session: session, amount: amount },
         xhr: true

    assert_response :success
    assert_nil assigns['warning']
    assert_equal orig_number_of_invoices + 1, client.invoices.count

    client.reload
    invoice = client.invoices[-1]
    assert_equal invoice.gross_amount, amount
    assert_equal invoice.status, TXN_CREATED
    assert_nil invoice.txn

    # We are not longer creating reminders for direct deposits
    reminder = client.reminders.where("owner_id=? AND owner_type='Invoice'", invoice.id).first
    assert_nil reminder

    fee = amount * 0.03
    tx = if alternate_tx
           alternate_tx
         else
           # correct payment information
           PaypalMockReply.new(payer_email: client.email,
                               first_name: client.fname,
                               last_name: client.lname)
         end

    tx.save
    tx.update_attributes(txn_id: get_txn,
                         business: Figaro.env.PAYPAL_BUSINESS_EMAIL,
                         mc_gross: amount,
                         mc_currency: 'USD',
                         mc_fee: fee,
                         payment_status: 'Completed',
                         payer_status: 'verified',
                         invoice: invoice.id,
                         txn_type: 'web_accept')

    # get the PayPal PDT
    if do_ipn
      post url_for(controller: :finance, action: :paypal_ipn), params: tx.attributes
    else
      post url_for(controller: :finance, action: :paypal_complete), params: { tx: tx.txn_id }
    end
    assert_response :success
    assert_nil assigns['retry']
    assert_nil assigns['errors']

    reminder = client.reminders.where("owner_id=? AND owner_type='Invoice'", invoice.id).first
    assert_nil reminder

    if do_coherency_tests
      add_deposit(amount)
      add_real_money(tx.mc_gross)

      invoice.reload
      assert_equal invoice.status, TXN_COMPLETED
      assert_equal invoice.txn, tx.txn_id

      account.reload
      assert_same_amount(balance_before + amount, account.balance)

      summary_money_check

      session = login(client)
      check_client_pages(client, session)
      logout(session)
    end

    tx.destroy

  end

  def get_txn
    Faker::Code.asin
  end

  def run_bid_payment_test(client, proj_name, do_ipn)

    # log in as a client
    project = setup_full_project(client, proj_name)
    revision = project.revisions[0]

    session = login(client)

    # release this revision
    post url_for(controller: :revisions, action: :edit_release_status, project_id: project.id, id: revision.id),
         params: { session: session, req: 'show' },
         xhr: true

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

    assert_not_equal 0, revision.lang_word_count(bid.revision_language.language)

    # accept the bid
    client_accepts_bids(session, [bid], BID_WAITING_FOR_PAYMENT)

    total = bid.total_cost
    assert_not_equal total, 0

    bid_account = bid.account
    assert bid_account
    assert_equal bid_account.balance, 0

    assert_difference 'Invoice.count', 1 do
      accept_list = {}
      ChatsController::BID_ACCEPT_CONDITIONS.size.times { |idx| accept_list[idx] = '1' }
      post pay_bids_with_paypal_project_revision_url(bid.revision.project, bid.revision),
           params: { session: session, accept: accept_list },
           as: :js

      assert_nil assigns(:warning)
      assert :redirect
    end

    assert_equal bid_account.reload.credits.count, 1
    transfer = bid_account.credits[0]
    assert_equal transfer.status, TRANSFER_PENDING

    invoice = client.invoices[-1] # Invoice.first
    assert invoice

    assert_equal invoice.status, TXN_CREATED

    client.reload
    fee = total * 0.03

    # lets start with some errors, to see that the payment is rejected
    tx = PaypalMockReply.new(txn_id: get_txn,
                             payer_email: 'orit_test@onthegosoft.com',
                             business: Figaro.env.PAYPAL_BUSINESS_EMAIL + 'x',
                             mc_gross: total - 0.1,
                             mc_currency: 'USD' + 'x',
                             mc_fee: fee,
                             payment_status: 'Completed' + 'x',
                             payer_status: 'verified',
                             invoice: invoice.id,
                             txn_type: 'web_accept')
    tx.save

    # get the PayPal PDT
    if do_ipn
      post url_for(controller: :finance, action: :paypal_ipn), params: tx.attributes
      assert_response :success
      # these assertion below do not exists in finance:paypal_complete because of the redirect for rejected paypal
      assert_nil assigns['retry']
      assert assigns['errors']
    else
      post url_for(controller: :finance, action: :paypal_complete), params: { tx: tx.txn_id }
      assert_response :redirect # it should definitely redirect because TX line 561 is expected to be rejected
    end

    invoice.reload
    assert_equal invoice.status, TXN_CREATED
    assert_nil invoice.txn

    # check with all parameters OK, except the amount
    tx.update_attributes(business: Figaro.env.PAYPAL_BUSINESS_EMAIL,
                         mc_gross: total - 0.02,
                         mc_currency: 'USD',
                         mc_fee: fee,
                         payment_status: 'Pending')

    # get the PayPal PDT
    if do_ipn
      post url_for(controller: :finance, action: :paypal_ipn), params: tx.attributes
      assert_response :success
      assert_nil assigns['retry']
      assert assigns['errors']
      assert_equal assigns['errors'].length, 1
    else
      post url_for(controller: :finance, action: :paypal_complete), params: { tx: tx.txn_id }
      assert_response :redirect
    end
    invoice.reload
    assert_equal invoice.status, TXN_CREATED
    assert_nil invoice.txn

    # see that it appears as a problem deposit
    problem_deposit = ProblemDeposit.where(txn: tx.txn_id).first
    assert problem_deposit
    assert_equal problem_deposit.status, ProblemDeposit::CREATED

    # # check with a pending transaction
    # tx.update_attributes(business: Figaro.env.PAYPAL_BUSINESS_EMAIL,
    #                      mc_gross: total,
    #                      mc_currency: 'USD',
    #                      mc_fee: fee,
    #                      payment_status: 'Pending')
    # # get the PayPal PDT
    # if do_ipn
    #   post url_for(controller: :finance, action: :paypal_ipn), params: tx.attributes
    # else
    #   post url_for(controller: :finance, action: :paypal_complete), params: { tx: tx.txn_id }
    # end
    # assert_response :success
    # assert_nil assigns['retry']
    # assert_nil assigns['errors']
    #
    # # check that the invoice was updated to the new status
    # invoice.reload
    # assert_equal invoice.status, TXN_PENDING
    # assert_equal invoice.txn, tx.txn_id
    #
    # # check that the money was not yet paid
    # bid_account.reload
    # assert_equal bid_account.balance, 0
    #
    # # now, check with a correct call
    # tx.update_attributes(business: Figaro.env.PAYPAL_BUSINESS_EMAIL,
    #                      mc_gross: total,
    #                      mc_currency: 'USD',
    #                      mc_fee: fee,
    #                      payment_status: 'Completed')
    #
    # # make sure the payment goes through after the session times out
    # logout(session)
    #
    # # do this twice. The first call should make the change, the 2nd should be ignored
    # for repeats in 0..1
    #   # get the PayPal PDT
    #   if do_ipn
    #     post url_for(controller: :finance, action: :paypal_ipn), params: tx.attributes
    #   else
    #     post url_for(controller: :finance, action: :paypal_complete), params: { tx: tx.txn_id }
    #   end
    #   if repeats == 0
    #     add_deposit(total)
    #     add_real_money(tx.mc_gross)
    #   end
    #
    #   assert_response :success
    #   assert_nil assigns['retry']
    #   assert_nil assigns['errors']
    #
    #   invoice.reload
    #   assert_equal invoice.status, TXN_COMPLETED
    #   assert_equal invoice.txn, tx.txn_id
    #
    #   reminder = client.reminders.where("owner_id=? AND owner_type='Invoice'", invoice.id).first
    #   assert_nil reminder
    #
    #   transfer.reload
    #   assert_equal transfer.status, TRANSFER_COMPLETE
    #
    #   bid_account.reload
    #   assert_same_amount(bid_account.balance, total)
    #
    #   # verify that no money went, by accident to the client account
    #   client.reload
    #   client.money_accounts.each do |money_account|
    #     money_account.reload
    #     # puts "balance in #{money_account.class.to_s} #{money_account.id} - #{money_account.balance}"
    #     assert_equal 0, money_account.balance
    #   end
    # end
    #
    # # finally, test just paypal_complete, without the PDT or IPN
    # post url_for(controller: :finance, action: :paypal_complete), params: tx.attributes
    # assert_response :success
    # assert assigns['invoice']
    # assert_equal assigns['invoice'].id, tx.invoice.to_i
    #
    # # check again with a bad txn_id
    # tx.update_attributes(invoice: 0)
    #
    # post url_for(controller: :finance, action: :paypal_complete), params: tx.attributes
    # assert_response :success
    # assert_nil assigns['invoice']
    #
    # summary_money_check
    #
    # translator_completes_work(xsession, chat)
    #
    # # now, complete the work and see that the fees have been paid too
    # session = login(client)
    # client_finalizes_bids(session, [bid])
    # summary_money_check
    # check_client_pages(client, session)
    # assert @root_account
    # logout(session)

    bid
  end

  # -------------- money integrity checking ----------------
  def init_money_checker
    @starting_money_total = total_money_in_system
    track_money_accounts
    reset_deposits

    @root_account = RootAccount.first
    @starting_fee = get_account_balance(@root_account)
  end

  def summary_money_check
    # check the integrity of all money accounts
    MoneyAccount.all.each { |money_account| check_account_integrity(money_account) }

    # see that no money was lost on the way
    @ending_money_total = total_money_in_system
    assert_same_amount(@starting_money_total + @deposits, @ending_money_total)

    # see that more real money entered than deposits
    assert_same_amount(@real_money, @deposits)

    total_fees = total_fees_paid

    if @root_account
      @root_account.reload
    else
      @root_account = RootAccount.first
    end

    if @root_account
      assert_same_amount(@starting_fee + total_fees, @root_account.balance)
    end

  end

  def reset_deposits
    @deposits = 0
    @real_money = 0
  end

  def add_deposit(val)
    @deposits += val
    # puts "making deposit: #{val} -> #{@deposits}"
  end

  def add_real_money(val)
    @real_money += val.to_f
    # puts "adding real money: #{val} -> #{@real_money}"
  end

  def track_money_accounts
    @initial_balance = {}
    for money_account in MoneyAccount.all
      @initial_balance[money_account.id] = money_account.balance
    end
  end

  def check_account_integrity(account)
    # check that the final balance matches
    # puts " -> checking #{account.class.to_s} #{account.id}"
    account.reload
    initial_balance = @initial_balance[account.id] || 0
    if account.account_lines.count == 0
      assert_equal initial_balance, account.balance
    else
      assert_equal account.balance.to_f, account.account_lines[-1].balance.to_f
    end

    prev_balance = initial_balance
    for account_line in account.account_lines
      addition = if account_line.money_transaction.source_account == account
                   -account_line.money_transaction.amount
                 elsif account_line.money_transaction.affiliate_account == account
                   account_line.money_transaction.fee * AFFILIATE_COMMISSION_RATE
                 elsif account.class == RootAccount
                   if account_line.money_transaction.affiliate_account
                     account_line.money_transaction.fee * (1 - AFFILIATE_COMMISSION_RATE)
                   else
                     account_line.money_transaction.fee
                   end
                 else
                   account_line.money_transaction.amount - account_line.money_transaction.fee
                 end

      # assert_not_equal 0, addition

      Rails.logger.info "Account: #{account.class}.#{account.id}: prev_balance: #{prev_balance}, addition: #{addition} = #{prev_balance + addition} /// account_line.balance: #{account_line.balance}"
      prev_balance += addition
      assert_same_amount(prev_balance, account_line.balance)

    end

  end

  def total_money_in_system
    sum = 0
    MoneyAccount.all.each { |account| sum += account.balance }
    sum
  end

  def total_fees_paid
    sum = 0
    MoneyTransaction.where('status=?', TRANSFER_COMPLETE).each do |transfer|
      sum += if transfer.affiliate_account
               transfer.fee * (1 - AFFILIATE_COMMISSION_RATE)
             else
               transfer.fee
             end
    end
    sum
  end

  # -----------
  def test_auto_accept_bid
    UserSession.delete_all
    client = users(:amir)

    # log in as a client
    project = setup_full_project(client, 'autoaccept')
    revision = project.revisions[0]

    session = login(client)

    # set the auto-accept amount
    auto_accept_amount = 0.09
    max_bid = 0.1
    post url_for(controller: :revisions, action: :edit_conditions),
         params: {
           session: session, req: 'save', project_id: project.id, id: revision.id,
           revision: {
             auto_accept_amount: (max_bid + 0.01),
             max_bid: max_bid,
             max_bid_currency: 1,
             bidding_duration: DAYS_TO_BID,
             project_completion_duration: DAYS_TO_COMPLETE_WORK
           }
         },
         xhr: true

    assert_response :success
    assert assigns(:warning)

    post url_for(controller: :revisions, action: :edit_conditions),
         params: {
           session: session, req: 'save', project_id: project.id, id: revision.id,
           revision: {
             auto_accept_amount: auto_accept_amount,
             max_bid: max_bid,
             max_bid_currency: 1,
             bidding_duration: DAYS_TO_BID,
             project_completion_duration: DAYS_TO_COMPLETE_WORK, word_count: 1
           }
         },
         xhr: true

    assert_response :success
    assert_nil assigns(:warning)

    # release this revision
    post url_for(controller: :revisions, action: :edit_release_status, project_id: project.id, id: revision.id),
         params: { session: session, req: 'show' },
         xhr: true

    assert_response :success
    assert_nil assigns(:warnings)

    logout(session)

    # log in as a translator
    translator1 = users(:orit)
    xsession1 = login(translator1)

    translator2 = users(:guy)
    xsession2 = login(translator2)

    chat_id1 = create_chat(xsession1, project.id, revision.id)
    chat1 = Chat.find(chat_id1)

    chat_id2 = create_chat(xsession2, project.id, revision.id)
    chat2 = Chat.find(chat_id2)

    language = languages(:Spanish)
    amount = MINIMUM_BID_AMOUNT
    bid1 = translator_bid(xsession1, chat1, language, max_bid, BID_GIVEN)

    bid2 = translator_bid(xsession2, chat2, language, max_bid, BID_GIVEN)

    # update the bid, so that it's auto accepted

    changenum = get_track_num(xsession1) # verify that the change is detected

    post url_for(controller: :chats, action: :save_bid, project_id: chat1.revision.project_id, revision_id: chat1.revision_id, id: chat1.id),
         params: { session: xsession1, bid: { amount: auto_accept_amount }, do_save: '1', lang_id: language.id, bid_id: bid1.id },
         xhr: true

    assert_response :success
    bid1.reload
    assert_equal BID_ACCEPTED, bid1.status

    changenum = assert_track_changes(xsession1, changenum, "Changenum didn't increment after bid was auto-accepted")

    post url_for(controller: :chats, action: :save_bid, project_id: chat2.revision.project_id, revision_id: chat2.revision_id, id: chat2.id),
         params: { session: xsession2, bid: { amount: auto_accept_amount }, do_save: '1', lang_id: language.id, bid_id: bid2.id },
         xhr: true

    assert_response :success
    bid2.reload
    assert_equal BID_GIVEN, bid2.status
  end
end
