require "#{File.dirname(__FILE__)}/../test_helper"

class WithdrawalTest < ActionDispatch::IntegrationTest
  fixtures :users, :money_accounts, :languages, :currencies, :projects, :revisions, :chats, :external_accounts, :identity_verifications

  def test_payment_for_bid

    @tx_sn = 0

    Project.destroy_all
    Invoice.destroy_all
    MoneyTransaction.destroy_all
    AccountLine.destroy_all
    Withdrawal.destroy_all
    MassPaymentReceipt.destroy_all
    Lock.destroy_all

    client = users(:amir)
    session = login(client)

    post_params = { params: { session: session } }

    post(url_for(controller: :finance, action: :index), post_params)
    assert_response :success

    orig_number_of_transactions = MoneyTransaction.count

    account = client.money_accounts[0]
    balance_before = account.balance

    external_account = client.external_accounts[0]
    assert external_account

    # show the withdraw box
    post(url_for(controller: :finance, action: :make_withdraw, id: account.id),
         xhr: true, params: { session: session, req: 'show' })
    assert_response :success
    assert_nil assigns['warning']
    assert_equal orig_number_of_transactions, MoneyTransaction.count

    # try to make a withdrawal, don't put in the amount
    post(url_for(controller: :finance, action: :make_withdraw, id: account.id),
         xhr: true, params: { session: session })
    assert_response :success
    assert assigns['warning']
    assert_equal orig_number_of_transactions, MoneyTransaction.count

    amounts = [12.0, 50, 3]

    # start a withdrawal with an amount
    post(url_for(controller: :finance, action: :make_withdraw, id: account.id),
         xhr: true, params: { session: session, amount: 5 })
    assert_response :success
    assert assigns['warning']
    assert_equal orig_number_of_transactions, MoneyTransaction.count

    # try to withdraw more than we have
    post(url_for(controller: :finance, action: :make_withdraw, id: account.id),
         xhr: true, params: { session: session, amount: balance_before + 1, to_account: external_account.id })
    assert_response :success
    assert assigns['warning']
    assert_equal orig_number_of_transactions, MoneyTransaction.count

    total_amount = 0
    num_withdrawals = 0
    amounts.each do |amount|
      # start a withdrawal with an amount
      post(url_for(controller: :finance, action: :make_withdraw, id: account.id),
           xhr: true, params: { session: session, amount: amount, to_account: external_account.id })
      assert_response :success
      assert_nil assigns['warning']
      num_withdrawals += 1
      assert_equal orig_number_of_transactions + num_withdrawals, MoneyTransaction.count

      total_amount += amount
      account.reload
      assert_same_amount balance_before - total_amount, account.balance

      money_transaction = MoneyTransaction.all.to_a[-1]
      assert_same_amount amount, money_transaction.amount
      assert_equal TRANSFER_REQUESTED, money_transaction.status
      assert_nil money_transaction.owner

    end

    logout(session)

    # ---------------- admin --------------------
    # now, log in as an admin, cancel one withdrawal and let the rest go
    admin = users(:admin)
    session = login(admin)

    post_params = { params: { session: session } }

    post(url_for(controller: :supporter, action: :index), post_params)
    assert_response :success

    post(url_for(controller: :supporter, action: :tasks), post_params)
    assert_response :success

    post(url_for(controller: :supporter, action: :requested_withdrawals), post_params)
    assert_response :success

    # delete the 1st request
    account.reload
    balance_before_cancel = account.balance
    to_delete = MoneyTransaction.first
    assert_equal TRANSFER_REQUESTED, to_delete.status
    post(url_for(controller: :supporter, action: :delete_requested_withdrawals),
         params: { session: session, request: { to_delete.id => 1 } })
    assert_response :redirect
    to_delete.reload
    assert_equal TRANSFER_CANCELED, to_delete.status
    account.reload
    assert_same_amount balance_before_cancel + to_delete.amount, account.balance

    # --------------- complete the pending mass payments -----------------
    requested_transactions = MoneyTransaction.where('status=?', TRANSFER_REQUESTED)

    # first attempt, get a failed response from masspay
    post(url_for(controller: :supporter, action: :do_mass_payments),
         params: { session: session, fail_in_debug: 1 })
    assert_response :redirect

    # get the mass payment withdrawal we just requested
    assert_equal 0, Withdrawal.count

    # see that all money transactions are as they were
    requested_transactions.each do |mt|
      assert_nil mt.owner
      assert_equal TRANSFER_REQUESTED, mt.status
    end

    post(url_for(controller: :supporter, action: :do_mass_payments),
         params: { session: session })
    assert_response :redirect

    # get the mass payment withdrawal we just requested
    withdrawal = Withdrawal.first
    assert withdrawal

    # make sure, all the money transactions are listed in this withdrawal (except the one we just canceled)
    assert_equal num_withdrawals - 1, withdrawal.mass_payment_receipts.length

    # check that all receipts have the correct status and that the money_transactions have updated
    withdrawal.mass_payment_receipts.each do |receipt|
      assert_nil receipt.txn
      assert_equal TXN_CREATED, receipt.status
      assert_equal TRANSFER_PENDING, receipt.money_transaction.status
    end

    logout(session)

    # ---------------- PayPal IPN notification that the payment is completed ---------------

    account.reload
    balance_before_ipn = account.balance

    # create the IPN masspay report
    ipn_report = { 'txn_type' => 'masspay', 'payment_status' => 'Completed' }
    idx = 0
    receipt_txn = {}
    txn_status = {}
    transfer_status = {}
    unclaimed_amount = 0
    withdrawal.mass_payment_receipts.each do |receipt|
      idx += 1

      txn_id = "TESTTXN#{idx}"
      ipn_report["unique_id_#{idx}"] = receipt.id
      if idx == 1
        ipn_report["status_#{idx}"] = 'Unclaimed'
        transfer_status[receipt.id] = TRANSFER_CANCELED
        unclaimed_amount += receipt.money_transaction.amount
      else
        ipn_report["status_#{idx}"] = TXN_COMPLETED_STRING
        transfer_status[receipt.id] = TRANSFER_COMPLETE
      end
      ipn_report["mc_fee_#{idx}"] = receipt.money_transaction.amount / 10
      ipn_report["masspay_txn_id_#{idx}"] = txn_id

      receipt_txn[receipt.id] = txn_id # remember this for later
      txn_status[receipt.id] = TXN_PAYMENT_STATUS[ipn_report["status_#{idx}"]]
    end

    post(url_for(controller: :finance, action: :paypal_ipn), params: ipn_report)

    account.reload
    assert_same_amount balance_before_ipn + unclaimed_amount, account.balance

    # make sure nothing remained locked at the end
    assert_equal 0, Lock.count

    # now, test that all the transactions are reported as completed
    withdrawal.mass_payment_receipts.each do |receipt|
      receipt.reload
      assert_equal receipt_txn[receipt.id], receipt.txn
      assert_equal txn_status[receipt.id], receipt.status
      assert_equal transfer_status[receipt.id], receipt.money_transaction.status
    end

    session = login(client)
    check_client_pages(client, session)
    logout(session)
  end

end
