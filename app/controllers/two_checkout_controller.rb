class TwoCheckoutController < ApplicationController
  SECRET_WORD = 'Vna3LZXEosMClnMXaIxqitMgq6g3uxCZW4HtoQBdfFgI3N58INJliA=='.freeze
  ACCOUNT_NUMBER = '102758938'.freeze

  prepend_before_action :authenticate_request, only: [:notification, :callback]
  before_action :get_invoice, only: [:notification, :callback]

  def notification
    # Message Type:
    #   ORDER_CREATED, FRAUD_STATUS_CHANGED, SHIP_STATUS_CHANGED,
    #   INVOICE_STATUS_CHANGED, REFUND_ISSUED, RECURRING_INSTALLMENT_SUCCESS,
    #   RECURRING_INSTALLMENT_FAILED, RECURRING_STOPPED, RECURRING_COMPLETE, RECURRING_RESTARTED
    logger.info "=== 2CO Notification #{params[:message_type]} === "

    case params[:message_type]
    when 'ORDER_CREATED'
      logger.info ' === 2CO Order Created === '
    when 'FRAUD_STATUS_CHANGED'
      case params[:fraud_status]
      when 'pass'
        logger.info '=== 2CO Fraud PASS === '
        if @invoice.status == TXN_COMPLETED
          logger.info ' === 2CO Invoice already paid. Ignoring request'
        else
          # invoice_kind     = Invoice::STAND_ALONE_DEPOSIT
          transaction_type = TRANSFER_DEPOSIT_FROM_EXTERNAL_ACCOUNT
          ext_account_find_attrs = {
            identifier: @invoice.user.email,
            external_account_type: EXTERNAL_ACCOUNT_2CHECKOUT
          }
          external_account = find_or_create_external_account(@invoice.user, ext_account_find_attrs)

          transaction = MoneyTransactionProcessor.transfer_money(
            external_account,
            @invoice.user.money_account,
            @invoice.gross_amount, # params[:li_0_price].to_f,
            DEFAULT_CURRENCY_ID,
            transaction_type,
            0
          )
          if transaction
            @invoice.update_attributes status: TXN_COMPLETED, modify_time: Time.now, txn: @txn_id
            transaction.owner = @invoice
            transaction.save

            if @invoice.cms_requests.present?
              website = @invoice.source
              # Reserve the amount corresponding to all CmsRequests that were paid
              # for so those funds can't be used for anything else.
              website.reserve_money_for_cms_requests(@invoice.cms_requests)
            end

            # @ToDo Create a Reminder notification
          end
        end
      when 'fail'
        logger.info '=== 2CO Fraud FAIL === '
        InternalMailer.billing('2CO Fraud FAIL [important]', "TXN: #{@txn_id}\r\nInvoice: #{@invoice.id}", params).deliver_now
      when 'wait'
        logger.info '=== 2CO Fraud WAIT === '
      end

    when 'REFUND_ISSUED'
      logger.info ' === 2CO Refund Issued === '
      InternalMailer.billing('2CO Refund Issued [important]', "TXN: #{@txn_id}\r\nInvoice: #{@invoice.id}", params).deliver_now
    else
      logger.info ' === 2CO ...Ignoring === '
    end

    render nothing: true
  end

  # this is the url that user is returned after a purchase
  def callback
    flash[:notice] = _('Thanks for your order. Your transaction is currently being processed. Funds will be available soon on your account.')

    redirect_to '/finance'
  end

  private

  # Notifications and Callback uses different parameters name,
  # thats why you see || to get the right value
  def authenticate_request
    @txn_id = params[:order_number] || params[:sale_id]
    @txn_id = '1' unless Rails.env.production?
    two_co_invoice_id = params[:invoice_id]
    two_co_hash = params[:key] || params[:md5_hash]

    # this is total including tax, li_0_price contain gross amount and li_1_price contain tax
    total = params[:total] || params[:invoice_list_amount]

    secret = if params[:action] == 'callback'
               "#{SECRET_WORD}#{ACCOUNT_NUMBER}#{@txn_id}#{total}"
             else
               "#{@txn_id}#{ACCOUNT_NUMBER}#{two_co_invoice_id}#{SECRET_WORD}"
             end

    # notification UPPERCASE(MD5_ENCRYPTED(Secret Word + Seller ID + 1 + Sale Total))
    hash = Digest::MD5.hexdigest(secret).upcase
    unless hash == two_co_hash
      logger.info '====2CO HASH MISMATCH ===='
      logger.info "secret_word: #{SECRET_WORD}"
      logger.info "account_number: #{ACCOUNT_NUMBER}"
      logger.info "order_number: #{@txn_id}"
      logger.info "2co_invoice_id: #{two_co_invoice_id}"
      logger.info "total: #{total}"
      logger.info "calculated hash: #{hash}"
      logger.info "given hash: #{two_co_hash}"

      set_err('Hash mismatch. Not valid request.')
      return
    end
    logger.info '==== 2CO Request Authenticated ==='
    logger.info "==== 2CO TXN: #{@txn_id} ==="
  end

  def get_invoice
    invoice_id = params[:merchant_order_id] || params[:vendor_order_id]

    @invoice = Invoice.find_by id: invoice_id
    return set_err('Invoice not found') unless @invoice

    if (Rails.env == 'production') && (params[:demo] == 'Y')
      set_err("You can't use demo mode on production")
    end
    if (Rails.env == 'production') && @invoice.demo
      set_err("This invoice was created as a demo. You can't pay it on production.")
    end

    if @invoice.status == TXN_COMPLETED
      logger.info ' ==== Invoice already paid ==== '
    end

    return logger.info '==== 2CO Error locating invoice ===' if @status
    logger.info "==== 2CO Invoice: #{@invoice.id} ==="
  end

  def find_or_create_external_account(user, find_attributes, create_attributes = {})
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
