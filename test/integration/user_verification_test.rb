require "#{File.dirname(__FILE__)}/../test_helper"

class UserVerificationTest < ActionDispatch::IntegrationTest
  fixtures :users, :languages

  def test_verify_with_correct_paypal_email
    init_email_deliveries

    user = users(:newbi)
    assert_equal false, user.verified?

    orig_todos = user.todos
    assert orig_todos[0] >= 1

    run_user_paypal_verification(user, user.email.capitalize)

    # user receives identity verification and another email for payment confirmation
    check_emails_delivered(2)

    assert_equal 1, user.identity_verifications.length
    iv = user.identity_verifications[-1]
    assert_equal VERIFICATION_OK, iv.status

    assert_equal orig_todos[0] - 1, user.todos[0]
    assert_equal true, user.verified?
  end

  def test_verify_with_other_paypal_email
    init_email_deliveries

    user = users(:newbi)
    assert_equal false, user.verified?

    orig_todos = user.todos
    assert orig_todos[0] >= 1

    email = user.email + 'x'
    run_user_paypal_verification(user, email)

    # user receives notification to verify ownership of email address and another email for payment confirmation
    check_emails_delivered(2)

    user.reload
    assert_equal 0, user.identity_verifications.length
    assert_equal orig_todos[0], user.todos[0]

    # now, the user validates the external account
    session = login(user)
    external_account = user.external_accounts[-1]
    assert external_account
    assert_equal PAYPAL_VERIFIED_EMAIL_STATUS, external_account.status
    get(url_for(controller: :users, action: :validate_external_account, id: user.id),
        session: session, acc_id: external_account.id, signature: external_account.signature)
    assert_response :redirect

    # check that the user is now validated
    user.reload
    assert_equal 1, user.identity_verifications.length
    iv = user.identity_verifications[-1]
    assert_equal VERIFICATION_OK, iv.status

    assert_equal orig_todos[0] - 1, user.todos[0]
    assert_equal true, user.verified?
    assert user.identity_verifications.where('status=?', VERIFICATION_OK).first

  end

  def run_user_paypal_verification(user, email)
    session = login(user)

    assert_equal 0, user.identity_verifications.length

    # go to the identity verifications page
    get(url_for(controller: :users, action: :verification, id: user.id),
        session: session)
    assert_response :success

    orig_number_of_invoices = user.invoices.count

    # show the deposit box
    xml_http_request(:post, url_for(controller: :users, action: :do_verification_deposit, id: user.id, format: :js),
                     session: session, req: 'show')
    assert_response :success
    assert_equal orig_number_of_invoices + 1, user.invoices.count

    amount = 0.1

    invoice = user.invoices[-1]
    assert_equal amount, invoice.gross_amount
    assert_equal TXN_CREATED, invoice.status
    assert_nil invoice.txn

    tx = PaypalMockReply.create(payer_email: email,
                                first_name: user.fname,
                                last_name: user.lname,
                                txn_id: get_txn,
                                business: Figaro.env.PAYPAL_BUSINESS_EMAIL,
                                mc_gross: amount,
                                mc_currency: 'USD',
                                mc_fee: amount * 0.2,
                                payment_status: 'Completed',
                                payer_status: 'verified',
                                invoice: invoice.id,
                                txn_type: 'web_accept')

    # get the PayPal IPN
    post(url_for(controller: :finance, action: :paypal_ipn), tx.attributes)
    assert_response :success
    assert_nil assigns['retry']
    assert_nil assigns['errors']

    invoice.reload
    assert_equal TXN_COMPLETED, invoice.status
    assert invoice.txn

    user.reload
  end

  def get_txn
    sn = SerialNumber.new
    "TESTTX#{sn.id}"
  end

  def test_verify_by_uploaded_document
    user = users(:newbi)
    session = login(user)
    assert_equal false, user.verified?

    orig_todos = user.todos
    assert orig_todos[0] >= 1

    supporter = users(:supporter)
    ssession = login(supporter)

    assert_equal 0, user.identity_verifications.length

    # go to the identity verifications page
    get(url_for(controller: :users, action: :verification, id: user.id),
        session: session)
    assert_response :success

    identity_verification = add_user_identity_document(session, user)
    decline_pending_user_identifications(ssession, supporter, identity_verification)

    identity_verification = add_user_identity_document(session, user)
    approve_pending_user_identifications(ssession, supporter, identity_verification)

    user.reload
    assert !user.identity_verifications.empty?
    iv = user.identity_verifications[-1]
    assert_equal VERIFICATION_OK, iv.status

    assert_equal orig_todos[0] - 1, user.todos[0]
    assert_equal true, user.verified?
  end

  def add_user_identity_document(session, user)
    # now, add a document and complete the request
    description = 'Document description'
    fname = 'sample/Initial/produced.xml.gz'
    multipart_post(
      url_for(controller: :users, action: :add_verification_document, id: user.id, target: 'frame'),
      session: session,
      description: description,
      uploaded_data: fixture_file_upload(fname, 'application/octet-stream'),
      format: :js
    )
    assert_response :success

    user.reload
    assert !user.user_identity_documents.empty?
    id_doc = user.user_identity_documents[-1]
    assert_equal description, id_doc.description

    assert !user.identity_verifications.empty?
    iv = user.identity_verifications[-1]
    assert_equal VERIFICATION_PENDING, iv.status
    iv
  end

  def approve_pending_user_identifications(session, _supporter, identity_verification)
    get(url_for(controller: :supporter), session: session)
    assert_response :success

    post(url_for(controller: :supporter, action: :approve_identity_verification, id: identity_verification.id))
    assert_response :redirect

    identity_verification.reload
    assert_equal VERIFICATION_OK, identity_verification.status
  end

  def decline_pending_user_identifications(session, _supporter, identity_verification)
    get(url_for(controller: :supporter), session: session)
    assert_response :success

    post(url_for(controller: :supporter, action: :decline_identity_verification, id: identity_verification.id))
    assert_response :redirect

    identity_verification.reload
    assert_equal VERIFICATION_DENIED, identity_verification.status
  end

end
