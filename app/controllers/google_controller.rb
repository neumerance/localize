class GoogleController < ApplicationController
  require 'rubygems'
  require 'net/https'
  require 'nokogiri'
  require 'rest-client'

  def process_payment
    # Get serial from google request
    @serial = params['serial-number']

    # Request the info from this serial
    res = send_xml "
    <notification-history-request xmlns=\"http://checkout.google.com/schema/2\">
      <serial-number>#{@serial}</serial-number>
    </notification-history-request>"

    # Taking money from client
    if res.css('authorization-amount-notification').text.any?
      order = res.css('google-order-number').first.text
      email = res.css('email').first.text
      amount = res.css('authorization-amount').first.text.to_f
      currency = res.css('authorization-amount').attr('currency').value
      nickname = res.css('item-name').text.gsub(/.*?for /, '').gsub(/ - invoice.*/, '')
      user = User.find_by(nickname: nickname)
      account = user.find_or_create_account(DEFAULT_CURRENCY_ID)

      raise 'Invalid currency!' unless currency == 'USD'
      raise "Can't find this user" unless user

      invoice_kind = Invoice::STAND_ALONE_DEPOSIT
      transaction_type = TRANSFER_DEPOSIT_FROM_EXTERNAL_ACCOUNT
      account_type = EXTERNAL_ACCOUNT_GOOGLE_CHECKOUT
      external_account = find_or_create_external_account(user, { identifier: email, external_account_type: account_type }, {})

      transaction = MoneyTransactionProcessor.transfer_money(external_account, account, amount, DEFAULT_CURRENCY_ID, transaction_type, 0)
      if transaction
        curtime = Time.now

        invoice = Invoice.new(kind: invoice_kind,
                              payment_processor: account_type,
                              currency_id: DEFAULT_CURRENCY_ID,
                              gross_amount: amount,
                              status: TXN_COMPLETED,
                              create_time: curtime,
                              modify_time: curtime,
                              txn: order)

        invoice.user = user
        invoice.save!

        transaction.owner = invoice
        transaction.save

        Rails.logger.info 'Deposit success!'
      else
        Rails.logger.info 'Deposit failed!'
      end
      Rails.logger.info "ORDER: #{order}"
      Rails.logger.info "E-MAIL: #{email}"
      Rails.logger.info "NICKNAME: #{nickname}"
      Rails.logger.info "AMOUNT: #{amount}"
      Rails.logger.info "CURRENCY: #{currency}"

    # Give money back to client
    elsif res.css('refund-amount-notification').text.any?
      order = res.css('google-order-number').first.text
      email = res.css('email').first.text
      amount = res.css('latest-refund-amount').first.text.to_f
      currency = res.css('authorization-amount').attr('currency').value
      logger.debug res.css('item-name').inspect
      nickname = res.css('item-name').text.gsub(/.*?for /, '').gsub(/ - invoice.*/, '')
      logger.debug nickname.inspect
      user = User.find_by(nickname: nickname)
      account = user.find_or_create_account(DEFAULT_CURRENCY_ID)

      raise 'Invalid currency!' unless currency == 'USD'
      raise "Can't find this user" unless user

      invoice_kind = Invoice::STAND_ALONE_WITHDRAWAL
      transaction_type = TRANSFER_GENERAL_REFUND
      account_type = EXTERNAL_ACCOUNT_GOOGLE_CHECKOUT
      external_account = find_or_create_external_account(user, { identifier: email, external_account_type: account_type }, {})

      transaction = MoneyTransactionProcessor.transfer_money(account, external_account, amount, DEFAULT_CURRENCY_ID, transaction_type, 0)
      if transaction
        curtime = Time.now

        invoice = Invoice.new(kind: invoice_kind,
                              payment_processor: account_type,
                              currency_id: DEFAULT_CURRENCY_ID,
                              gross_amount: amount,
                              status: TXN_COMPLETED,
                              create_time: curtime,
                              modify_time: curtime,
                              txn: order)

        invoice.user = account.normal_user
        invoice.save!

        transaction.owner = invoice
        transaction.save

        Rails.logger.info 'Withdraw success!'
      else
        Rails.logger.info 'Withdraw failed!'
      end
      Rails.logger.info "ORDER: #{order}"
      Rails.logger.info "E-MAIL: #{email}"
      Rails.logger.info "NICKNAME: #{nickname}"
      Rails.logger.info "AMOUNT: #{amount}"
      Rails.logger.info "CURRENCY: #{currency}"
    end

    # Render the view to notify that this serial number was handled
  end

  private

  def send_xml(xml)
    if Rails.env == 'production'
      merchant_id = '803540621247356'
      merchant_key = 'hMo3NWNnpy9IrsTYteTMMg'
      url = 'checkout.google.com'
      google_post = "/api/checkout/v2/reports/Merchant/#{merchant_id}"

    else
      merchant_id = '366683439993601'
      merchant_key = 'abn7gx5f1JH67EE7Pai1bg'
      url = 'sandbox.google.com'
      google_post = "/checkout/api/checkout/v2/reports/Merchant/#{merchant_id}"
    end

    http = Net::HTTP.new(url, 443)
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_PEER
    http.ca_file = Rails.root + '/certs/cacert.pem'

    req = Net::HTTP::Post.new(google_post)
    req.body = xml
    req.basic_auth(merchant_id, merchant_key)

    res_body2 = http.request(req)
    res_body = res_body2.body
    Rails.logger.debug res_body
    Nokogiri::XML(res_body)
  end

  def find_or_create_external_account(user, find_attributes, create_attributes)
    attempt = 1
    ok = false
    while !ok && (attempt < 10)
      external_account = ExternalAccount.where(find_attributes).first
      if external_account
        # if (user[:type] != 'TemporaryUser') && (external_account.normal_user != user)
        #	logger.info "external account already belongs to someone else: #{external_account.normal_user.class}.#{external_account.normal_user.id}"
        #	return nil
        # end
        ok = true
      else
        begin
          external_account = ExternalAccount.new(find_attributes.merge(create_attributes))
          external_account.normal_user = user if user[:type] != 'TemporaryUser'
          external_account.save!
          ok = true
        rescue
        end
        attempt += 1
      end
    end

    if ok
      return external_account
    else
      return nil
    end
  end
end
