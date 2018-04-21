module CreateDeposit
  def create_deposit_from_external_account(user, amount, currency_id, processor = EXTERNAL_ACCOUNT_PAYPAL, website_id = nil)
    curtime = Time.zone.now

    source = website_id ? Website.find(website_id) : user

    # Check if we already have a PENDING invoice for a direct deposit.
    Invoice.delete_previous_duplicate user, source, Invoice::DEPOSIT_TO_ACCOUNT

    invoice = Invoice.new(
      kind: Invoice::DEPOSIT_TO_ACCOUNT,
      payment_processor: processor,
      currency_id: currency_id,
      gross_amount: amount,
      status: TXN_CREATED,
      create_time: curtime,
      modify_time: curtime,
      demo: Rails.env != 'production',
      website_id: website_id,
      source: source,
      user: user
    )

    invoice.set_tax_information
    invoice.save!

    # create the transfer and include it in the invoice
    to_account = user.find_or_create_account(currency_id)

    MoneyTransaction.create!(
      amount: amount,
      currency_id: currency_id,
      chgtime: curtime,
      status: TRANSFER_PENDING,
      operation_code: TRANSFER_DEPOSIT_FROM_EXTERNAL_ACCOUNT,
      owner: invoice,
      target_account: to_account
    )

    # @ToDo only create if there is a tax to transfer
    # Create a transfer for tax
    MoneyTransaction.create!(
      amount: invoice.tax_amount,
      currency_id: currency_id,
      chgtime: curtime,
      status: TRANSFER_PENDING,
      operation_code: TRANSFER_TAX_RATE,
      owner: invoice,
      target_account: TaxAccount.find_or_create
    )

    invoice.create_reminder if website_id.present?

    # create the next step according to the payment processor type
    case processor
    when EXTERNAL_ACCOUNT_PAYPAL
      @url = paypal_pay_invoice(invoice, user, url_for(controller: :finance, action: :index, session: @user_session.session_num))
    when EXTERNAL_ACCOUNT_2CHECKOUT
      prepare_2checkout_url(user, invoice, amount)
    else
      raise 'Invalid external processor type'
    end

    redirect_to(@url) && (return true) unless request.xhr?

    if @user_session.display == COMPACT_SESSION
      render 'shared/deposit_from_external_account/show_modal'
    else
      render 'shared/deposit_from_external_account/update_location'
    end

    true
  end

  private

  def prepare_2checkout_url(user, invoice, amount)
    @url = if CO_ENABLED
             'https://www.2checkout.com/checkout/purchase'
           else
             'https://icanlocalize.com'
           end
    receipt_link = url_for(controller: '/two_checkout', action: :callback)

    parameters = {
      sid: 102_758_938,
      mode: '2CO',
      li_0_name: format('Deposit to ICanLocalize account for %s - invoice #%d', user.nickname, invoice.id),
      li_0_price: format('%.2f', amount),
      x_receipt_link_url: receipt_link,
      merchant_order_id: invoice.id
    }

    if invoice.tax_amount > 0
      parameters.merge!(
        li_1_type: 'tax',
        li_1_name: format('%s%% VAT Tax in %s', user.tax_rate, user.country.name),
        li_1_price: format('%.2f', invoice.tax_amount)
      )
    end

    parameters['demo'] = 'Y' unless Rails.env.production?

    @url += '?' + parameters.to_query
    logger.info "Payment url: #{@url}"
    @url
  end
end
