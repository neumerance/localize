# This module is *not* auto-reloaded in the development environment. The Rails
# server must be restarted for any changes to take effect.
module TransactionProcessor
  TRANSACTION_SAVE_STAGE = 1
  TRANSACTION_RETRY_STAGE = 2

  # executes @transaction_to_complete
  # the argument is not passed, but rather is a global variable for this class
  # so that the yield blocks can modify it
  def move_money_between_accounts
    curtime = Time.now

    from_account  = @transaction_to_complete.source_account
    to_account    = @transaction_to_complete.target_account
    amount        = @transaction_to_complete.amount.ceil_money
    fee           = @transaction_to_complete.fee.ceil_money

    if fee != 0
      root_account = RootAccount.find_or_create
      affiliate_account = @transaction_to_complete.affiliate_account
    end

    net_amount = amount - fee
    attempt = 1
    ok = false
    force_abort = false

    while !ok && !force_abort && (attempt < MAX_RETRY_ATTEMPTS)
      if from_account.has_balance? && ((from_account.balance + 0.01) < amount)
        return false
      end

      ok = false
      begin
        MoneyAccount.transaction do

          force_abort = !yield(TRANSACTION_SAVE_STAGE) if block_given?

          unless force_abort
            if from_account.has_balance?
              StaleObjHandler.retry do
                from_account.update_attributes(balance: (from_account.balance - amount))
              end
              from_account_line = AccountLine.new(balance: from_account.balance,
                                                  chgtime: curtime)
              from_account_line.account = from_account
              from_account_line.money_transaction = @transaction_to_complete
              from_account_line.save!
            end

            if to_account.has_balance?
              StaleObjHandler.retry do
                to_account.update_attributes(balance: (to_account.balance + net_amount))
              end
              to_account_line = AccountLine.new(balance: to_account.balance,
                                                chgtime: curtime)
              to_account_line.account = to_account
              to_account_line.money_transaction = @transaction_to_complete

              if @transaction_to_complete.owner.is_a? Invoice
                to_account_line.txn_id = @transaction_to_complete.owner&.txn
              end

              to_account_line.save!
            end

            if fee != 0
              if affiliate_account
                affiliate_fee = fee * AFFILIATE_COMMISSION_RATE
                root_fee = fee * (1 - AFFILIATE_COMMISSION_RATE)
              else
                root_fee = fee
              end

              StaleObjHandler.retry do
                root_account.update_attributes(balance: (root_account.balance + root_fee))
              end
              fee_account_line = AccountLine.new(balance: root_account.balance,
                                                 chgtime: curtime)
              fee_account_line.account = root_account
              fee_account_line.money_transaction = @transaction_to_complete
              fee_account_line.save!

              if affiliate_account
                StaleObjHandler.retry do
                  affiliate_account.update_attributes(balance: (affiliate_account.balance + affiliate_fee))
                end
                affiliate_account_line = AccountLine.new(balance: affiliate_account.balance,
                                                         chgtime: curtime)
                affiliate_account_line.account = affiliate_account
                affiliate_account_line.money_transaction = @transaction_to_complete
                affiliate_account_line.save!
              end

            end
          end
        end

        ok = true unless force_abort
      rescue StandardError => problem
        from_account.reload
        to_account.reload
        root_account.reload if root_account

        force_abort = !yield(TRANSACTION_RETRY_STAGE) if block_given?

        attempt += 1
      end
    end
    unless ok
    end
    ok
  end

  # This method is widely called
  #   there is also other method with same name on money_transaction_processor.rb
  def transfer_money(from_account, to_account, amount, currency_id, operation_code, fee_rate = 0, affiliate_user = nil)
    fee = amount * fee_rate

    root_account = (RootAccount.find_or_create if fee != 0)

    affiliate_account_id = if affiliate_user
                             affiliate_user.find_or_create_account(currency_id).id
                           end

    @transaction_to_complete = MoneyTransaction.new(amount: amount,
                                                    fee: fee,
                                                    chgtime: Time.now,
                                                    fee_rate: fee_rate,
                                                    currency_id: currency_id,
                                                    status: TRANSFER_COMPLETE,
                                                    operation_code: operation_code,
                                                    affiliate_account_id: affiliate_account_id)
    @transaction_to_complete.source_account = from_account
    @transaction_to_complete.target_account = to_account
    transaction_attributes = @transaction_to_complete.attributes

    transaction_res = move_money_between_accounts do |stage|
      if stage == TRANSACTION_SAVE_STAGE
        if to_account.class == BidAccount
          selected_bid = to_account.bid.revision_language.selected_bid
          return false if selected_bid && (selected_bid != to_account.bid)
        end
        @transaction_to_complete.save!
      else
        @transaction_to_complete = MoneyTransaction.new
        transaction_attributes.each { |k, v| @transaction_to_complete[k] = v }
      end
      true
    end

    if transaction_res
      return @transaction_to_complete
    else
      return nil
    end

  end

  def reverse_money_transaction(money_transaction, reverse_code)
    curtime = Time.now

    return false if money_transaction.status == TRANSFER_CANCELED

    return_net_amount = money_transaction.amount - money_transaction.fee

    # create a reverse transaction
    reverse_transaction = MoneyTransaction.new(amount: return_net_amount,
                                               fee: -money_transaction.fee,
                                               currency_id: money_transaction.currency.id,
                                               chgtime: curtime,
                                               status: TRANSFER_COMPLETE,
                                               operation_code: reverse_code)
    # set the source and destination account for the reversal transaction
    reverse_transaction.target_account = money_transaction.source_account
    reverse_transaction.source_account = money_transaction.target_account

    # associate the reveral with the original canceled transaction
    reverse_transaction.owner = money_transaction

    reverse_transaction_attributes = reverse_transaction.attributes

    root_account = (RootAccount.find_or_create if money_transaction.fee > 0)

    @transaction_to_complete = reverse_transaction
    transaction_res = move_money_between_accounts do |stage|
      if stage == TRANSACTION_SAVE_STAGE
        @transaction_to_complete.save!
        money_transaction.update_attributes(status: TRANSFER_CANCELED)
      else
        @transaction_to_complete.MoneyTransaction.new
        @transaction_to_complete.update_attributes(reverse_transaction_attributes)
        money_transaction.reload
        money_transaction.status != TRANSFER_CANCELED
      end
    end

    transaction_res
  end

  # this is used when customer pays with account balance,
  # if user user paypal to pay Invoice#create_for_bids is used
  def create_invoice_for_bids(currency_id, user_account, user, revision, bids, additional_total = 0)
    curtime = Time.now

    # first, calculate the total
    transfer_total = additional_total
    bids.each { |bid| transfer_total += revision.cost_for_bid(bid).ceil_money }

    invoice = Invoice.new(kind: Invoice::PAYMENT_FOR_TRANSLATION_WORK,
                          payment_processor: EXTERNAL_ACCOUNT_PAYPAL,
                          currency_id: currency_id,
                          gross_amount: transfer_total,
                          status: TXN_CREATED,
                          create_time: curtime,
                          modify_time: curtime)

    invoice.user = user
    invoice.save!

    invoice.create_reminder

    # 2) Create a transfer of the total amount to the client's account
    money_transaction = MoneyTransaction.new(amount: transfer_total,
                                             currency_id: currency_id,
                                             chgtime: curtime,
                                             status: TRANSFER_PENDING,
                                             operation_code: TRANSFER_DEPOSIT_FROM_EXTERNAL_ACCOUNT)
    money_transaction.owner = invoice
    money_transaction.target_account = user_account
    money_transaction.save!

    # 3) Create a transfer for each of the bids to the bid account
    bids.each do |bid|
      # bid.revision_language.delete_reminders(EVENT_NEW_BID)

      # Money transaction for translations
      if bid.waiting_for_payment?
        transfer_amount = bid.translator_payment
        money_transaction = MoneyTransaction.new(amount: bid.translator_payment,
                                                 currency_id: currency_id,
                                                 chgtime: curtime,
                                                 status: TRANSFER_PENDING,
                                                 operation_code: TRANSFER_DEPOSIT_FROM_EXTERNAL_ACCOUNT)
        money_transaction.owner = invoice
        money_transaction.source_account = user_account
        money_transaction.target_account = bid.find_or_create_account
        money_transaction.save!
      end

      # Money transaction for reviews
      next unless bid.managed_work.pending_payment?
      money_transaction = MoneyTransaction.new(amount: bid.reviewer_payment,
                                               currency_id: currency_id,
                                               chgtime: curtime,
                                               status: TRANSFER_PENDING,
                                               operation_code: TRANSFER_DEPOSIT_TO_PROJECT_REVIEW)
      money_transaction.owner = invoice
      money_transaction.source_account = user_account
      money_transaction.target_account = bid.find_or_create_account
      money_transaction.save!
    end

    invoice
  end

  def create_invoice_for_reviews(currency_id, user_account, user, revision, bids, additional_total = 0)
    curtime = Time.now

    # first, calculate the total
    transfer_total = additional_total
    bids.each { |bid| transfer_total += revision.reviewer_payment(bid) }

    invoice = Invoice.new(kind: Invoice::PAYMENT_FOR_TRANSLATION_WORK,
                          payment_processor: EXTERNAL_ACCOUNT_PAYPAL,
                          currency_id: currency_id,
                          gross_amount: transfer_total,
                          status: TXN_CREATED,
                          create_time: curtime,
                          modify_time: curtime)

    invoice.user = user
    invoice.save!

    invoice.create_reminder

    # 2) Create a transfer of the total amount to the client's account
    money_transaction = MoneyTransaction.new(amount: transfer_total,
                                             currency_id: currency_id,
                                             chgtime: curtime,
                                             status: TRANSFER_PENDING,
                                             operation_code: TRANSFER_DEPOSIT_FROM_EXTERNAL_ACCOUNT)
    money_transaction.owner = invoice
    money_transaction.target_account = user_account
    money_transaction.save!

    # 3) Create a transfer for each of the bids to the bid account
    for bid in bids
      transfer_amount = revision.reviewer_payment(bid)

      money_transaction = MoneyTransaction.new(amount: transfer_amount,
                                               currency_id: currency_id,
                                               chgtime: curtime,
                                               status: TRANSFER_PENDING,
                                               operation_code: TRANSFER_DEPOSIT_TO_PROJECT_REVIEW)
      money_transaction.owner = invoice
      money_transaction.source_account = user_account
      money_transaction.target_account = bid.find_or_create_account
      money_transaction.save!

      # indicate that the review jobs are waiting for payment
      revision_language = bid.revision_language
      if revision_language.managed_work
        revision_language.managed_work.update_attributes(active: MANAGED_WORK_PENDING_PAYMENT)
      else
        managed_work = ManagedWork.new(active: MANAGED_WORK_PENDING_PAYMENT,
                                       translation_status: MANAGED_WORK_CREATED,
                                       from_language_id: revision_language.revision.language_id,
                                       to_language_id: revision_language.language_id)
        managed_work.client = revision_language.revision.project.client
        managed_work.owner = revision_language
        managed_work.notified = 0
        managed_work.save!
      end

    end

    invoice
  end

  # Called from software projects: text_resources#deposit_payment
  def create_invoice_for_resource_languages(currency_id, user_money_account, user, text_resource, transfer_total,
                                            resource_language_costs)
    curtime = Time.now

    # Check if we already have a PENDING invoice for a direct deposit.
    Invoice.delete_previous_duplicate user, text_resource, Invoice::PAYMENT_FOR_TRANSLATION_WORK

    invoice = Invoice.new(kind: Invoice::PAYMENT_FOR_TRANSLATION_WORK,
                          payment_processor: EXTERNAL_ACCOUNT_PAYPAL,
                          currency_id: currency_id,
                          gross_amount: transfer_total,
                          status: TXN_CREATED,
                          create_time: curtime,
                          modify_time: curtime,
                          source: text_resource)

    invoice.user = user

    invoice.set_tax_information

    invoice.save!

    invoice.create_reminder

    # 2) Create a transfer of the total amount to the client's account
    money_transaction = MoneyTransaction.new(
      amount: transfer_total,
      currency_id: currency_id,
      chgtime: curtime,
      status: TRANSFER_PENDING,
      operation_code: TRANSFER_DEPOSIT_FROM_EXTERNAL_ACCOUNT
    )
    money_transaction.owner = invoice
    money_transaction.target_account = user_money_account
    money_transaction.save!

    # 3) Create a transfer for each of the resource_language's account
    resource_language_costs.each do |transfer_amount, resource_language_or_kwp, transaction_code|
      money_transaction = MoneyTransaction.new(
        amount: transfer_amount,
        currency_id: currency_id,
        chgtime: curtime,
        status: TRANSFER_PENDING,
        operation_code: transaction_code
      )
      money_transaction.owner = invoice
      money_transaction.source_account = user_money_account
      money_transaction.target_account = resource_language_or_kwp.find_or_create_account
      money_transaction.save!
    end

    # 4) Create a transfer for tax
    # Todo: Why we are not adding a source account here?
    # Todo: This is being created even if tax is 0, is that okey?
    money_transaction = MoneyTransaction.new(
      amount: invoice.tax_amount,
      currency_id: currency_id,
      chgtime: curtime,
      status: TRANSFER_PENDING,
      operation_code: TRANSFER_TAX_RATE
    )
    money_transaction.owner = invoice
    money_transaction.target_account = TaxAccount.find_or_create
    money_transaction.save!

    invoice
  end

  def create_invoice_for_wpml_website(cms_requests_to_pay, amount_without_taxes, payment_processor_code)
    raise 'Expected to receive at least one cms_request' if cms_requests_to_pay.blank?
    raise "Amount must be bigger than zero, was #{amount_without_taxes}" \
      if amount_without_taxes.blank? || amount_without_taxes <= 0

    website = cms_requests_to_pay.first.website
    # All cms_requests must belong to a single website
    return unless cms_requests_to_pay.pluck(:website_id).uniq == [website.id]

    current_time = Time.now
    client_account = website.client.find_or_create_account(DEFAULT_CURRENCY_ID)

    # Create the invoice
    invoice = Invoice.create!(
      kind: Invoice::PAYMENT_FOR_TRANSLATION_WORK,
      payment_processor: payment_processor_code,
      user: website.client,
      currency_id: DEFAULT_CURRENCY_ID,
      # The gross_amount attribute is NOT meant to include taxes. The Invoice
      # model calculates the taxes based on the user's country.
      gross_amount: amount_without_taxes,
      status: TXN_CREATED,
      source: website,
      cms_requests: cms_requests_to_pay,
      create_time: current_time,
      modify_time: current_time
    )
    # Calculate taxes (e.g., VAT) and fill the tax_amount attribute.
    invoice.set_tax_information
    # Invoice#set_tax_information requires it to be saved to persist the tax info.
    invoice.save!
    invoice.create_reminder

    # Transfer money to the client's account
    MoneyTransaction.create!(
      amount: amount_without_taxes,
      currency_id: DEFAULT_CURRENCY_ID,
      chgtime: current_time,
      status: TRANSFER_PENDING,
      operation_code: TRANSFER_DEPOSIT_FROM_EXTERNAL_ACCOUNT,
      owner: invoice,
      target_account: client_account
    )

    if invoice.tax_amount > 0
      # Create a transfer for tax
      MoneyTransaction.create!(
        amount: invoice.tax_amount,
        currency_id: DEFAULT_CURRENCY_ID,
        chgtime: current_time,
        status: TRANSFER_PENDING,
        operation_code: TRANSFER_TAX_RATE,
        owner: invoice,
        target_account: TaxAccount.find_or_create
      )
    end

    invoice
  end

  # in order to mark a transaction as complete, it needs to be in either TRANSFER_PENDING or TRANSFER_REQUESTED state
  # since updates to the money_transactions may fail, it is being attempted several times
  def mark_transaction_as_complete(money_transaction)
    ok = false

    StaleObjHandler.retry(MAX_RETRY_ATTEMPTS) do
      ok = if [TRANSFER_REQUESTED, TRANSFER_PENDING].include?(money_transaction.status)
             money_transaction.update_attributes(status: TRANSFER_COMPLETE)
           else
             false
           end
    end

    ok
  end

  def withdraw_to_external_account(amount, currency_id, from_account, to_account)
    money_transaction = MoneyTransaction.new(amount: amount,
                                             fee: 0,
                                             currency_id: currency_id,
                                             chgtime: Time.now,
                                             status: TRANSFER_REQUESTED,
                                             operation_code: TRANSFER_PAYMENT_TO_EXTERNAL_ACCOUNT)
    money_transaction.source_account = from_account
    money_transaction.target_account = to_account

    @transaction_to_complete = money_transaction
    transaction_attributes = @transaction_to_complete.attributes

    transaction_res = move_money_between_accounts do |stage|
      if stage == TRANSACTION_SAVE_STAGE
        @transaction_to_complete.save!
      else
        @transaction_to_complete = MoneyTransaction.new
        @transaction_to_complete.update_attributes(transaction_attributes)
      end
    end

    if transaction_res
    end

    transaction_res

  end

  # Called from FinanceController#paypal_ipn and FinanceController#paypal_complete (PDT)
  def update_invoice(invoice, update_invoice_attributes, external_account)
    logger.info "::::::::::::: Updating invoice #{invoice.id}"
    # clear any reminders for this invoice
    invoice.reminders.delete_all

    # the invoice may be accessed by someone else. Make sure we manage to write to it
    ok = false
    StaleObjHandler.retry do
      if invoice.status == update_invoice_attributes[:status]
        logger.info "::::::::::::: Invoices already has status #{update_invoice_attributes[:status]} for #{invoice.id}, returning true"
        return true
      end
      logger.info "::::::::::::: Updating invoice status from #{invoice.status} to #{update_invoice_attributes[:status]}"
      ok = invoice.update_attributes!(update_invoice_attributes)
    end

    # if we couldn't update the invoice, we have to abort
    unless ok
      logger.info "::::::::::::: NOT ABLE TO UPDATE THE INVOICE #{invoice.id}. Returning false from transaction_processor#update_invoice"
      return false
    end

    if invoice.status == TXN_COMPLETED
      # if the invoice is completed, finish all money_transactions and bids
      all_ok = true
      logger.info "::::::::::::: TXN COMPLETED for #{invoice.id}"
      invoice.money_transactions.each do |money_transaction|
        next unless money_transaction.source_account || external_account
        source_account_ok = money_transaction.source_account && (money_transaction.source_account.class != ExternalAccount)

        @transaction_to_complete = money_transaction

        @transaction_to_complete.status = TRANSFER_COMPLETE
        @transaction_to_complete.chgtime = Time.now
        unless source_account_ok
          @transaction_to_complete.source_account = external_account
        end

        Rails.logger.info "  Processing MoneyTransaction #{@transaction_to_complete.id} source_account: #{@transaction_to_complete.source_account.class}##{@transaction_to_complete.source_account.id}"

        transaction_res = move_money_between_accounts do |stage|
          if stage == TRANSACTION_SAVE_STAGE
            @transaction_to_complete.save!
          else
            @transaction_to_complete.reload
            @transaction_to_complete.status = TRANSFER_COMPLETE
            @transaction_to_complete.chgtime = Time.now
            unless source_account_ok
              @transaction_to_complete.source_account = external_account
            end
          end
          true
        end

        # If move money was succesful process according to project type
        if transaction_res
          logger.info "::::::::::::: Transaction RES:#{transaction_res}"
          logger.info "::::::::::::: Target Account class:#{money_transaction.target_account.class}"

          # A website Translation (WPML) project has received a successful
          # payment.
          if @invoice.cms_requests.present? && money_transaction.operation_code == TRANSFER_DEPOSIT_FROM_EXTERNAL_ACCOUNT
            # A website Translation (WPML) project has received a successful payment
            website = invoice.source
            # Reserve the amount corresponding to all CmsRequests that were paid
            # for so those funds can't be used for anything else.
            website.reserve_money_for_cms_requests(invoice.cms_requests)

            logger.info 'Received payment confirmation for website translation ' \
                        "project: website #{website.id}, invoice #{@invoice.id}, " \
                        "gross amount #{@invoice.gross_amount}, net amount " \
                        "#{@invoice.net_amount}."
          end

          if money_transaction.target_account.class == BidAccount
            if money_transaction.operation_code == TRANSFER_DEPOSIT_TO_PROJECT_REVIEW
              money_transaction.target_account.bid.start_review
            elsif !money_transaction.target_account.bid.update_bid_to_accepted
              all_ok = false
            end
          elsif money_transaction.target_account.class == ResourceLanguageAccount
            resource_language = money_transaction.target_account.resource_language
            resource_chat = resource_language.selected_chat
            text_resource = resource_chat.resource_language.text_resource

            if [TRANSFER_DEPOSIT_TO_RESOURCE_TRANSLATION,
                TRANSFER_DEPOSIT_TO_RESOURCE_TRANSLATION_WITH_REVIEW,
                TRANSFER_DEPOSIT_TO_RESOURCE_TRANSLATION_WITH_REVIEW_AND_KEYWORDS,
                TRANSFER_DEPOSIT_TO_RESOURCE_REVIEW_WITH_KEYWORDS,
                TRANSFER_DEPOSIT_TO_RESOURCE_KEYWORDS].include?(money_transaction.operation_code)

              review_enabled = [TRANSFER_DEPOSIT_TO_RESOURCE_TRANSLATION_WITH_REVIEW,
                                TRANSFER_DEPOSIT_TO_RESOURCE_REVIEW_WITH_KEYWORDS,
                                TRANSFER_DEPOSIT_TO_RESOURCE_TRANSLATION_WITH_REVIEW_AND_KEYWORDS].include?(money_transaction.operation_code)

              untranslated_strings = text_resource.untranslated_strings(resource_chat.resource_language.language)
              resource_chat.send_strings_to_translation(text_resource, untranslated_strings, money_transaction.amount, review_enabled)
              resource_chat.update_attributes!(translation_status: RESOURCE_CHAT_PENDING_TRANSLATION)
            else
              unreviewed_strings = text_resource.unreviewed_strings(resource_chat.resource_language.language)
              resource_chat.send_strings_to_review(text_resource, resource_language, unreviewed_strings, money_transaction.amount)
            end

            text_resource.update_version_num

          elsif money_transaction.target_account.class == KeywordAccount
            money_transaction.target_account.keyword_project.pay!
          end
        else
          all_ok = false
        end
      end

      total = invoice.gross_amount if all_ok && invoice.website_id

      if all_ok
        begin
          if invoice.user.can_receive_emails?
            ReminderMailer.invoice_paid(invoice).deliver_now
          end
        rescue
        end
      end
      return all_ok
    else
      # otherwise, there's nothing more to do
      return true
    end

  end

end
