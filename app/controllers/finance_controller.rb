class FinanceController < ApplicationController
  include ::ProcessorLinks
  include ::CreateDeposit

  prepend_before_action :setup_user, except: [:paypal_complete, :paypal_ipn]
  layout :determine_layout
  before_action :verify_no_manager
  before_action :verify_admin, only: [:new_manual_invoice, :create_manual_invoice, :new_wire_transfer, :wire_transfer]
  before_action :verify_account_ownership, only: [:make_deposit, :make_withdraw]
  before_action :verify_invoice_ownership, only: [:invoice, :delete_invoice, :edit_invoice_company, :complete_invoice, :edit_invoice_status]
  before_action :create_reminders_list, only: [:index, :invoice, :invoices, :account_history]
  before_action :setup_help, except: [:paypal_complete, :paypal_ipn]
  before_action :view_finances, only: [:index, :account_history, :deposits, :withdrawals]
  before_action :set_account, only: %i(account_history account_graph deposits withdrawals new_wire_transfer)

  skip_before_action :verify_authenticity_token, only: [:paypal_ipn]

  def index
    @header = _('Your financials')
    @pending_invoices_count = @user.pending_invoices.count
    @can_deposit = @user.is_client? || (@user[:type] == 'Partner')

    # -- see if this user has already made a withdrawal
    money_account_ids = @user.money_accounts.collect(&:id)
    unless money_account_ids.empty?
      @pending_money_transaction =
        MoneyTransaction.
        where('(chgtime > ?)
              AND (status = ?)
              AND (operation_code = ?)
              AND (source_account_type = ?) AND (source_account_id in (?))',
              Time.now - (12 * 60 * 60),
              TRANSFER_REQUESTED,
              TRANSFER_PAYMENT_TO_EXTERNAL_ACCOUNT,
              'MoneyAccount',
              money_account_ids).first
    end

    @account = @user.money_account

  end

  def account_graph
    unless @user.has_supporter_privileges?
      redirect_to '/'
      return
    end

    @dots = @account.credits.count + @account.payments.count
    @dots = 1000 if @account.credits.count + @account.payments.count > 1000
    @data = @account.data_for_graph
  end

  def account_history
    owner = if @user.has_admin_privileges?
              if @account.class == UserAccount
                @account.normal_user.full_name + "'s"
              elsif @account.class == BidAccount
                'bid'
              elsif @account.class == RootAccount
                'system fees'
              elsif @account.class == ResourceLanguageAccount
                "Software project to #{@account.resource_language.language.name}"
              else
                'unknown'
              end
            else
              'your'
            end

    @details = !params[:details].blank?

    @account_lines = @account.account_lines.order('account_lines.id DESC').page(params[:page]).per(params[:per_page])

    @header = _('History of %s %s account') % [owner, @account.currency.name]
  end

  def deposits
    set_time_range

    @account_lines = @account.account_lines.
                     joins(:money_transaction).
                     where('(money_transactions.target_account_type=?) AND (money_transactions.target_account_id=?) AND (money_transactions.chgtime >= ?) AND (money_transactions.chgtime <= ?)', 'MoneyAccount', @account.id, @start_time, @end_time).
                     order('account_lines.id DESC').page(params[:page]).per(params[:per_page])

    @total = 0
    @account_lines.each { |al| @total += al.money_transaction.amount }

    @unpaginated = true

    @header = _('Summary of deposits to your ICanLocalize account')
  end

  def withdrawals
    set_time_range

    @account_lines = @account.account_lines.
                     joins(:money_transaction).
                     where('(money_transactions.target_account_type=?) AND (money_transactions.chgtime >= ?) AND (money_transactions.chgtime <= ?)', 'ExternalAccount', @start_time, @end_time).
                     order('account_lines.id DESC')

    @total = 0
    @account_lines.each { |al| @total += al.money_transaction.amount }

    @unpaginated = true

    @header = _('Summary of withdrawals from your ICanLocalize account')
  end

  def pending_cms_requests
    if params[:id]
      set_account
    else
      @account = @user.find_or_create_account(DEFAULT_CURRENCY_ID)
    end

    target_languages = @account.cms_target_languages.where(status: CMS_TARGET_LANGUAGE_CREATED)

    @pager = ::Paginator.new(target_languages.count, PER_PAGE) do |offset, per_page|
      target_languages.limit(per_page).offset(offset).order('cms_target_languages.id ASC')
    end

    @cms_target_languages = @pager.page(params[:page])
    @list_of_pages = []
    (1..@pager.number_of_pages).to_a.each { |idx| @list_of_pages << idx }

    @total = @account.pending_total_expenses

    @header = _('Pending expenses to your account')
  end

  def new_wire_transfer; end

  def wire_transfer
    account = UserAccount.find_by(id: params[:id])
    client = account.normal_user
    unless account
      set_err("Account doesn't exists!")
      return
    end

    unless %w(withdraw deposit).include?(params[:type])
      flash[:notice] = 'Unknown transaction type'
      redirect_to :back
      return
    end

    if params[:fee].blank? || params[:gross_amount].blank?
      flash[:notice] = 'You need to specify both fee and gross amount values'
      redirect_to :back
      return
    end

    if params[:txn].blank? || params[:txn].include?(' ')
      flash[:notice] = 'You need to fill the transaction bank ID account correctly. Only the transaction ID should appear on the field.'
      redirect_to :back
      return
    end

    if params[:gross_amount].to_f == 0
      flash[:notice] = 'gross amount should be bigger than zero'
      redirect_to :back
      return
    end

    amount = params[:gross_amount].to_f
    fee = params[:fee].to_f

    external_account = find_or_create_external_account(@user, { identifier: @user.email, external_account_type: EXTERNAL_ACCOUNT_BANK_TRANSFER }, {})
    case params[:type]
    when 'withdraw'
      invoice_kind = Invoice::STAND_ALONE_WITHDRAWAL
      transaction_type = TRANSFER_PAYMENT_TO_EXTERNAL_ACCOUNT
      to_account = external_account
      from_account = account
    when 'deposit'
      invoice_kind = Invoice::STAND_ALONE_DEPOSIT
      transaction_type = TRANSFER_DEPOSIT_FROM_EXTERNAL_ACCOUNT
      to_account = account
      from_account = external_account
      needs_invoice = true
    else
      raise 'Invalid type'
    end

    transaction = MoneyTransactionProcessor.transfer_money_fixed_fee(from_account, to_account, amount, transaction_type, fee)

    unless transaction
      flash[:notice] = 'Trasaction could not be completed!'
      redirect_to :back
      return
    end

    curtime = Time.now

    if needs_invoice
      invoice = Invoice.new(kind: invoice_kind,
                            payment_processor: EXTERNAL_ACCOUNT_BANK_TRANSFER,
                            currency_id: DEFAULT_CURRENCY_ID,
                            gross_amount: amount - fee,
                            status: TXN_COMPLETED,
                            create_time: Time.now,
                            modify_time: Time.now,
                            txn: params[:txn])
      invoice.user = account.normal_user
      invoice.save!

      transaction.owner = invoice
      transaction.save!
    end

    flash[:notice] = 'Money transaction processed!'
    if needs_invoice
      redirect_to action: :invoice, id: invoice.id
    else
      redirect_to controller: :finance, action: :account_history, id: account
    end

  end

  def new_manual_invoice
    @header = 'Manual deposit or withdraw'

    @account = if @user.has_supporter_privileges?
                 MoneyAccount.find_by(id: params[:id])
               else
                 UserAccount.find_by(id: params[:id])
               end

    unless @account
      set_err('Cannot find this account')
      return
    end

    # if !['Client', 'Alias', 'Translator', 'Partner'].include? @account.normal_user[:type]
    # set_err('You can only deposit and withdraw from normal user accounts')
    # return
    # end

    if params[:invtype] == 'deposit'
      @default_transfer_type = 0
    elsif params[:invtype] == 'withdraw'
      @default_transfer_type = 1
    end

    @transfer_types = { 0 => "Deposit to user's account", 1 => "Withdrawal from user's account" }
    @currency = Currency.find(DEFAULT_CURRENCY_ID)
    @external_account_types = [
      [
        'Manual transfer', EXTERNAL_ACCOUNT_CHECK
      ]
    ]
  end

  def create_manual_invoice
    warnings = []

    @account = if @user.has_supporter_privileges?
                 MoneyAccount.find_by(id: params[:id])
               else
                 UserAccount.find_by(id: params[:id])
               end

    unless @account
      set_err('Cannot find this account')
      return
    end

    if !params[:transfer_type].blank?
      transfer_type = params[:transfer_type].to_i
      if transfer_type == 0
        invoice_kind = Invoice::STAND_ALONE_DEPOSIT
        transaction_type = TRANSFER_DEPOSIT_FROM_EXTERNAL_ACCOUNT
      elsif transfer_type == 1
        invoice_kind = Invoice::STAND_ALONE_WITHDRAWAL
        transaction_type = TRANSFER_PAYMENT_TO_EXTERNAL_ACCOUNT
      else
        warnings << 'Bad transfer type'
      end
    else
      warnings << 'Transfer type not selected'
    end

    if !params[:account_type].blank?
      account_type = params[:account_type].to_i
      unless ExternalAccount::NAME.keys.include?(account_type)
        warnings << 'External account type not selected'
      end
    else
      warnings << 'External account type not selected'
    end

    txid = params[:txid].blank? ? nil : params[:txid]

    if (transfer_type != 0) && txid.blank?
      warnings << 'Transaction ID not specified'
    end

    if !params[:amount].blank?
      amount = params[:amount].to_f
      if amount <= 0
        warnings << 'Amount must be positive. Change the transaction type for reverse transactions.'
      elsif (transfer_type == 1) && (amount > @account.balance)
        warnings << 'Amount greater than account balance. Maximal withdrawal is %s %s' % [@account.balance, @account.currency.name]
      end
    else
      warnings << 'Amount must be specified'
    end

    if warnings.empty?
      external_account = find_or_create_external_account(@user, { identifier: @user.email, external_account_type: account_type }, {})
      unless external_account
        @warnings = ['This external account already belongs to a different user']
        @header = 'Serious problem'
        return
      end

      transaction = if transfer_type == 0
                      MoneyTransactionProcessor.transfer_money(external_account, @account, amount, @account.currency_id, transaction_type, 0)
                    else
                      MoneyTransactionProcessor.transfer_money(@account, external_account, amount, @account.currency_id, transaction_type, 0)
                    end

      if transaction && @account.is_a?(UserAccount)
        curtime = Time.now

        @invoice = Invoice.new(kind: invoice_kind,
                               payment_processor: account_type,
                               currency_id: @account.currency_id,
                               gross_amount: amount,
                               status: !txid.blank? ? TXN_COMPLETED : TXN_PENDING,
                               create_time: curtime,
                               modify_time: curtime,
                               txn: txid)

        @invoice.user = @account.normal_user
        @invoice.save!

        transaction.owner = @invoice
        transaction.save

        @header = 'Transaction complete'
      elsif transaction
        @header = 'Transaction complete'
      else
        @header = 'Transfer failed'
        @warnings = ['Transfer failed. Try again']
      end
    else
      @warnings = warnings
      @header = 'Transaction failed'
    end
  end

  def invoices
    if params[:status] == 'pending'
      @header = _('Outstanding invoices')
      invoices = @user.pending_invoices
      @mode = 'pending'
    else
      @header = _('Invoices')
      invoices = @user.completed_invoices
      @mode = 'completed'
    end

    @pager = ::Paginator.new(invoices.count, PER_PAGE) do |offset, per_page|
      invoices.limit(per_page).offset(offset).order('id DESC')
    end
    @invoices_page = @pager.page(params[:page])
    @list_of_pages = []
    for idx in 1..@pager.number_of_pages
      @list_of_pages << idx
    end
    @show_number_of_pages = (@pager.number_of_pages > 1)
    @invoices_exist = !invoices.empty?
  end

  def invoice
    # set up the list of possible actions
    @possible_actions = []
    if @invoice.status == TXN_CREATED
      invoice_payment_link = paypal_pay_invoice(@invoice, @user,
                                                url_for(action: :invoice, id: @invoice.id))
      money_account = @user.find_or_create_account(@invoice.currency_id)

      # TwoCheckout payment confirmation can take days to arrive. We disable
      # the "Pay" and "Delete" buttons to prevent the user from paying again
      # or deleting the invoice before the payment confirmation arrives.
      unless @invoice.payment_processor == EXTERNAL_ACCOUNT_2CHECKOUT
        @possible_actions << if money_account.balance < @invoice.gross_amount || @invoice.source_type == 'User'
                               [_('Proceed to %s to complete this payment') % ExternalAccount::NAME[@invoice.payment_processor], invoice_payment_link, nil]
                             else
                               [_('Use your existing balance to pay for this work'), url_for(action: :complete_invoice, id: @invoice.id), _('Are you sure you want to transfer the funds for this work?')]
                             end
        @possible_actions << [_('Delete this invoice'), url_for(action: :delete_invoice, id: @invoice.id), _('Are you sure you want to delete this invoice?')]
      end
    end

    @header = _('Invoice #%d') % @invoice.id
    respond_to do |format|
      format.html
      format.pdf do
        disp = params[:disp] || 'inline'
        render  pdf:                            "otgs_invoice_#{@invoice.id}",
                disposition:                    disp,
                show_as_html:                   params.key?('debug'),
                orientation:                    'Portrait',
                page_size:                      'A4',
                title:                          'Alternate Title',
                dpi:                            '600',
                encoding:                       'UTF-8',
                no_pdf_compression:             true,
                grayscale:                      false,
                lowquality:                     false,
                enable_plugins:                 true,
                disable_internal_links:         true,
                disable_external_links:         true,
                print_media_type:               true,
                disable_smart_shrinking:        true,
                use_xserver:                    true,
                background:                     false,
                no_background:                  true,
                extra:                          '',
                margin: { bottom: 30 },
                footer: { html: { template: 'finance/invoice_footer.pdf.erb' } }
      end
    end
  end

  def complete_invoice
    update_attributes = { status: TXN_COMPLETED }
    res = update_invoice(@invoice, update_attributes, nil)
    flash[:notice] = res ? _('Payment completed successfully') : _('Payment could not be completed')
    redirect_to action: :invoice, id: @invoice.id
  end

  def mass_payment_receipt
    @header = 'Details of payment'
    begin
      @mass_payment_receipt = MassPaymentReceipt.find(params[:id])
    rescue
      set_err('Cannot find this receipt')
      return
    end
    if !@user.has_admin_privileges? &&
       (@mass_payment_receipt.money_transaction.source_account.normal_user != @user) &&
       (@mass_payment_receipt.money_transaction.target_account.normal_user != @user)
      set_err('You cannot view this payment')
      return
    end
  end

  def delete_invoice
    if [TXN_CREATED, TXN_PENDING].include?(@invoice.status)
      if @invoice.status == TXN_PENDING && @invoice.payment_processor == EXTERNAL_ACCOUNT_2CHECKOUT
        flash[:notice] = _('2CO does not allow us to delete this invoice, please contact support.')
      else
        @invoice.destroy
      end
    else
      flash[:notice] = _('This invoice has been completed and cannot be deleted')
    end
    redirect_to action: :invoices
  end

  def make_test_deposit
    create_deposit_from_external_account(@user, 0.1, DEFAULT_CURRENCY_ID)
  end

  # this is used from:
  #   - The user's finance page to make a direct deposit
  #  - /web_supports/untranslated_messages (Instant translation)
  def make_deposit
    website_id = params[:website_id]

    if @user.alias? && !@user.alias_profile.financial_deposit
      set_err("You don't have permission to do that")
      return
    end

    @show_deposit = nil # set the default value - don't show the list
    req = params[:req]
    if req == 'show' # @ToDo check when this is used and write a comment
      @show_deposit = true
      expenses, pending_cms_target_languages, pending_web_messages = @account.pending_total_expenses
      @amount = expenses - @account.balance
      @amount = 0 if @amount < 0

      @total = 0
      @tax_rate = @user.try(:tax_rate) || 0
      if @user.has_to_pay_taxes?
        @tax_amount = @user.calculate_tax @amount
        @total += @tax_amount
      end
      @total += @amount

    elsif (req == 'save') || req.nil?
      amount = params[:amount].to_f
      if amount <= 0
        @warning = _('Deposit amount must be greater than 0')
        return
      end

      processor = (params[:processor] || EXTERNAL_ACCOUNT_PAYPAL).to_i

      unless create_deposit_from_external_account(@user, amount, DEFAULT_CURRENCY_ID, processor, website_id)
        @warning = _('Could not send to payment processor. Please choose a different type.')
        return
      end

    end
  end

  def deposit_fund
    errors = []
    errors << 'Please define deposit amount' if params[:amount].to_f <= 0
    flash[:notice] = errors.join('<br />')
    if errors.present?
      redirect_to :back
    else
      create_deposit_from_external_account(@user, params[:amount].to_f, DEFAULT_CURRENCY_ID, params[:payment_processor].to_i)
    end
  rescue => e
    flash[:notice] = 'We are not able to process your request at this time, please contact support.'
    redirect_to :back
  end

  def make_withdraw

    if @user.alias?
      set_err("You don't have permission to do that")
      return
    end

    @show_withdraw = nil # set the default value - don't show the list
    req = params[:req]
    if req == 'show'
      @show_withdraw = true
      @withdraw_confirmation_message = _('This withdrawal will be completed within the next 24 hours. You will receive a confirmation message once completed.')
      @amount = @account.balance

    elsif (req == 'save') || req.nil?
      withdraw_account_id = params[:to_account].to_i
      logger.info " ------------ selected to_account: #{withdraw_account_id}"
      begin
        withdraw_account = ExternalAccount.find(withdraw_account_id)
      rescue
        @warning = "Can't find withdraw_account: #{withdraw_account_id}"
        return
      end

      # verify that it actually belongs to this user
      if withdraw_account.normal_user != @user
        @warning = 'Not your account'
        return
      end

      amount = params[:amount].to_f
      if amount <= 0
        @warning = _('withdrawal amount must be greater than 0')
        return
      end

      if amount >= 10000
        @warning = _('Withdrawal amount must be lower than 10,000 USD. You can do more withdraws for a higher value.')
        return
      end

      currency = Currency.find(DEFAULT_CURRENCY_ID) # put something a little better here
      @withdrawn = withdraw_to_external_account(amount, currency.id, @account, withdraw_account)
      unless @withdrawn
        @warning = _('withdrawal amount cannot exceed account balance (%.2f)') % @account.balance
      end

      return if @warning
    end
  end

  # PayPal payment notification
  #     Example:
  # charset: windows-1252
  # item_name: Deposit to account
  # payment_type: instant
  # payment_fee: "1.00"
  # txn_type: web_accept
  # txn_id: 57614564MY9889916
  # invoice: "27034"
  # payer_id: BSN68WUBQZD5S
  # residence_country: US
  # business: f.tanus-facilitator@gmail.com
  # mc_gross: "24.00"
  # handling_amount: "0.00"
  # ipn_track_id: 68673087905d8
  # notify_version: "3.8"
  # shipping: "0.00"
  # verify_sign: A8JvLV-g8K1CRHo6GGmLMUy4uXJdAFGvJwF-Mz.1mxh4-P8kkJdMlZnc
  # last_name: test
  # payment_status: Completed
  # payer_status: verified
  # test_ipn: "1"
  # protection_eligibility: Ineligible
  # mc_currency: USD
  # quantity: "1"
  # receiver_id: 54ZM79R79ZJYG
  # first_name: test
  # payment_gross: "24.00"
  # transaction_subject: ""
  # payment_date: 21:33:04 Apr 12, 2015 PDT
  # custom: ""
  # item_number: ""
  # tax: "4.00"
  # receiver_email: f.tanus-facilitator@gmail.com
  # payer_email: me@arnoldroa.com
  # mc_fee: "1.00"
  def paypal_ipn
    # first, the call is checked against PayPal to validate authenticity
    validator = PaypalValidator.new(logger)
    if validator.validate_ipn(request.raw_post)
      txn_id = params['txn_id']
      @result = process_paypal_request(txn_id, params)
      logger.info "----------- IPN validation PASSED for #{txn_id}"
    else
      @result = 'not validated'
      logger.info '---------- IPN validation FAILED'
    end
  end

  # PayPal transaction complete page
  # @ToDo Check result and redirect to right page, params is empty.
  def paypal_complete
    ok = false
    tx = params[:tx]
    logger.info '------------ PARAMS ------------'
    logger.info params.to_yaml
    logger.info "------------ TX: #{tx}"
    if !tx.blank?
      validator = PaypalValidator.new(logger)
      if validator.validate_pdt(tx)
        logger.info "---------- PDT validation PASSED for #{tx}"
        if process_paypal_request(tx, validator.arguments)
          ok = true
          logger.info '---------- processed invoice OK'
        end
      else
        session[:last_url] = []
        logger.info "---------- PDT validation FAILED for #{tx}"
        flash[:notice] = 'Payment failed. Please try again.'
        # Payment for WPML translation
        if @invoice && @invoice.source_type == Website
          # TODO: Create a session for the user to prevent him from having to login again.
          redirect_to wpml_website_translation_jobs_path
        else # Other payments
          redirect_to '/'
        end
      end
    elsif !params[:txn_id].blank?
      # see if this is a regular PayPal return, without PDT
      setup_invoice_for_user(params['invoice'].to_i)
      ok = true if @invoice
    else
      flash[:notice] = 'Your payment has been processed.'
      session[:last_url] = []
      redirect_to '/finance'
      logger.info '---------- NO PDT or other arguments'
    end

    if ok
      # check the result of the paid invoice
      if @invoice.status == TXN_COMPLETED
        @header = _('Your Payment is Complete')
        if @invoice.kind == Invoice::PAYMENT_FOR_TRANSLATION_WORK
          # get a money transaction for this invoice which goes to a bid
          money_transaction = @invoice.money_transactions.where('money_transactions.source_account_type=?', 'MoneyAccount').first
          if money_transaction.nil?
            @description = _('The translator has been notified of your payment and can start working immediately.')
            @next_actions = [[_('View the details of this payment'), url_for(action: :invoice, id: @invoice.id)],
                             [_('Go to your home'), url_for(controller: :client)]]
          elsif money_transaction.target_account.class == BidAccount
            chat = money_transaction.target_account.bid.chat
            @description = _('The translator has been notified of your payment and can start working immediately.')
            @next_actions = [[_('View the details of this payment'), url_for(action: :invoice, id: @invoice.id)],
                             [_('Chat with the translator'), url_for(controller: :chats, action: :show, project_id: chat.revision.project_id, revision_id: chat.revision_id, id: chat.id)],
                             [_('Go to your home'), url_for(controller: :client)]]
          elsif money_transaction.target_account.class == ResourceLanguageAccount
            text_resource = money_transaction.target_account.resource_language.text_resource
            @description = _('The translators have been notified of your payment and can start working immediately.')
            @next_actions = [[_('View the details of this payment'), url_for(action: :invoice, id: @invoice.id)],
                             [_('Go to the project page'), url_for(controller: :text_resources, action: :show, id: text_resource.id)],
                             [_('Go to your home'), url_for(controller: :client)]]
          end
        elsif @invoice.kind == Invoice::DEPOSIT_TO_ACCOUNT
          @description = _('Your deposit is complete. These funds are now available in your ICanLocalize account.')
          @next_actions = [[_('View the details of this payment'), url_for(action: :invoice, id: @invoice.id)],
                           [_('Go to your home'), url_for(controller: :client)]]
        elsif @invoice.kind == Invoice::INSTANT_TRANSLATION_PAYMENT
          @user = @invoice.user
          @session_num = create_session_for_user(@user)
          message = _("We've started working on your translation!")

          @description = '<p><b>' + message + '</b></p>' \
                         '<p>' + _("To pick up the translation, once it's complete you'll need to log in with the following email and password:") + '</p>' \
                         '<ul><li>' + _('E-Mail') + ': <b>' + @user.email + '</b></li><li>' +
                         _('Password') + ': <b>****</b></li></ul>' \
                         '<div class="errorExplanation"><h3>' + _('IMPORTANT') + '</h3><p>' +
                         _("We'll send you update messages, regarding the progress of this translation. Make sure that your SPAM filter doesn't block our email address: %s") % "<b>#{RAW_EMAIL_SENDER}</b>" \
                         '</p></div>'
          @next_actions = [[_('View the details of this payment'), url_for(action: :invoice, id: @invoice.id)],
                           [_('Check translation status'), url_for(controller: :web_messages)]]
        end
      elsif @invoice.status == TXN_PENDING
        @header = _('Your payment is being processed')
        @description = '<p>' + _('Your payment has been started and is now being processed.') + ' ' +
                       _('Depending on the payment method, your payment will be complete within a few days.') + ' ' +
                       _('To check on the exact status of your payment and the expected completion date, please log in to your <a href="https://www.paypal.com/">PayPal</a> account.') + '</p>'
        @description +=
          if @invoice.kind == Invoice::PAYMENT_FOR_TRANSLATION_WORK
            '<p>' + _('The translator will be notified once your payment clears and will be able to start working.') + '</p>'
          else
            '<p>' + _('These funds will be available in your ICanLocalize account once this payment completes.') + '</p>'
          end
        @next_actions = [[_('View the details of this payment'), url_for(action: :invoice, id: @invoice.id)],
                         [_('Go to your home'), url_for(controller: :client)]]
      end
    end

  end

  def edit_invoice_company
    req = params[:req]

    @show_edit = nil
    if req.nil?
      @invoice.update_attributes!(company: params[:company])
    elsif req == 'del'
      @invoice.update_attributes!(company: nil)
    elsif req == 'show'
      @invoice.company = @invoice.default_company if @invoice.company.nil?
      @show_edit = true
    end
  end

  def edit_invoice_status
    req = params[:req]

    @show_edit = nil
    reload = false

    if req.nil?
      status = params[:completed].to_i == 1 ? TXN_COMPLETED : TXN_PENDING
      if (status == TXN_COMPLETED) && (params[:txn].blank? || params[:account_type].blank?)
        @warning = 'TXN cannot be blank if the transaction is complete'
      else
        pay = params[:pay]
        if pay
          update_attributes = { txn: params[:txn], payment_processor: params[:account_type].to_i, status: TXN_COMPLETED }
          external_account = @invoice.user.external_accounts.where('external_account_type=?', EXTERNAL_ACCOUNT_CREDITCARD).first
          unless external_account
            external_account = ExternalAccount.new(external_account_type: EXTERNAL_ACCOUNT_CREDITCARD, status: 'verified', identifier: @invoice.user.email)
            external_account.normal_user = @invoice.user
            external_account.save!
          end

          res = update_invoice(@invoice, update_attributes, external_account)
          if !res
            @warning = 'Could not complete this invoice'
          else
            reload = true
          end
        else
          @invoice.update_attributes!(txn: params[:txn], payment_processor: params[:account_type].to_i, status: status)
          reload = true if status == TXN_COMPLETED
        end
      end
    elsif req == 'show'
      @show_edit = true
      @external_account_types = [['Select', 0], ['------', 0]] + ExternalAccount::NAME.keys.sort.collect do |k|
        [ExternalAccount::NAME[k].capitalize, k]
      end
    end
    @reload = reload
  end

  def external_account
    begin
      @external_account = ExternalAccount.find(params[:id].to_i)
    rescue
      set_err('Cannot locate this account')
      return
    end

    if !@user.has_admin_privileges? && ![@user, @user.master_account].include?(@external_account.normal_user)
      set_err('You cannot view this page')
      return
    end

    set_time_range

    @header = _('Information about external account')
    @credits = @external_account.credits.where('(money_transactions.chgtime >= ?) AND (money_transactions.chgtime <= ?)', @start_time, @end_time)
    @total_credits = 0
    @credits.each { |c| @total_credits += c.amount }

    @total_payments = 0
    @payments = @external_account.payments.where('(money_transactions.chgtime >= ?) AND (money_transactions.chgtime <= ?)', @start_time, @end_time)
    @payments.each { |c| @total_payments += c.amount }
  end

  def payment_methods
    @header = _('Payment methods')
  end

  private

  def verify_admin
    unless @user.has_admin_privileges?
      set_err('You are not authorized to view this')
      false
    end
  end

  def process_paypal_request(tx, params_dict)
    txn_type = params_dict['txn_type']
    if txn_type == 'web_accept'
      process_web_accept(tx, params_dict)
    elsif txn_type == 'masspay'
      process_mass_pay(params_dict)
    else
      return false
    end
  end

  # Web Accept is used for paying invoices
  def process_web_accept(tx, params_dict)
    # get the invoice this payment is for
    invoice_id = params_dict['invoice'].to_i

    # check if an external account has been set for this email address
    email    = params_dict['payer_email']
    fname    = params_dict['first_name']
    lname    = params_dict['last_name']
    status   = params_dict['payer_status']

    # get the gross, tax and net amount
    mc_gross = params_dict['mc_gross'].to_f
    mc_fee   = params_dict['mc_fee'].to_f
    tax      = params_dict['tax'].to_f

    # get the transaction information
    mc_currency = params_dict['mc_currency']
    business = params_dict['business']
    payment_status = params_dict['payment_status']

    # Create a list of invoices, even if paying only for one
    # @ToDo we have an to_i on invoice_id previously, i think this will never
    #   contain multiples ids, I've also checked in logs and we done have one
    #   single ipn request that contains a comma.
    if invoice_id.to_s.include? ','
      Rails.logger.info '-- invoice_id with comma detected --'
      invoices_ids = invoice_id.split(',') if invoice_id
    else
      invoices_ids = [invoice_id.to_s]
    end

    # This call sets the @invoice and checks that the call arguments match
    invoices_ids.each do |iid|
      unless validate_invoice_details(invoices_ids, mc_gross, tax, mc_currency, business, payment_status)
        abort_purchase(tx, iid, @error_codes)
        return false
      end
    end
    logger.info "::::::::::::: Paying for invoices: #{@invoices.map(&:id).join(',')}"

    # get the external account for these invoices
    external_accounts = {}
    @invoices.each do |invoice|
      if !external_account = find_or_create_external_account(invoice.user, { identifier: email, external_account_type: EXTERNAL_ACCOUNT_PAYPAL }, fname: fname, lname: lname)
        abort_purchase(tx, invoice_id, [[Invoice::CANT_FIND_EXTERNAL_ACCOUNT, "For email #{email}, invoice: #{invoice.id}"]])
        return false
      else
        external_accounts[invoice] = external_account
      end
    end
    logger.info "::::::::::::: External accounts: #{external_accounts.inspect}"

    was_temp_user = false
    if @invoices.first.user[:type] == 'TemporaryUser'
      was_temp_user = true
      migrate_temporary_user_to_normal(@invoices.first.user, external_accounts[@invoices.first])
      @invoices.each(&:reload)
      external_accounts[@invoices.first].reload
    end

    # update the external account details only if it belongs to the right user
    external_account = external_accounts[@invoices.first]
    if was_temp_user || (external_account.normal_user == @invoices.first.user)
      # update the status of the external account per this transaction
      if (external_account.status != status) || (external_account.fname != fname) || (external_account.lname != lname)
        external_account.update_attributes(status: status, fname: fname, lname: lname)
      end
      external_account.update_user_verification unless was_temp_user
    end

    # WebMessage: Update the create time for any messages that were not funded before.
    #   this way, translators will get the notification message
    @invoices.each do |invoice|
      next unless invoice.user[:type] == 'Client'
      invoice.user.money_accounts.each do |account|
        WebMessage.joins(:money_account).
          where('(money_accounts.id = ?) AND (web_messages.translation_status = ?)',
                account.id, TRANSLATION_NEEDED).each do |m|
          StaleObjHandler.retry { m.update_attributes(create_time: Time.now) }
        end
      end
    end

    net_amount = mc_gross - mc_fee - tax
    update_attributes = {
      net_amount: net_amount,
      payment_processor: EXTERNAL_ACCOUNT_PAYPAL,
      txn: tx,
      status: TXN_PAYMENT_STATUS[payment_status]
    }

    res = true
    orig_invoice_status = {}
    @invoices.each do |invoice|
      orig_invoice_status[invoice] = invoice.status
      res = update_invoice(invoice, update_attributes, external_account)
      unless res
        abort_purchase(tx, invoice.id, [[Invoice::CANT_UPDATE_INVOICE, "invoice: #{invoice.id}"]])
        return false
      end
    end

    @invoices.each do |invoice|
      next unless (invoice.kind == Invoice::INSTANT_TRANSLATION_PAYMENT) && (invoice.status == TXN_COMPLETED) && (invoice.status != orig_invoice_status[invoice])
      message = _("We've started working on your translation! When it's complete, we will send you another email.")
      begin
        if invoice.user.can_receive_emails?
          ReminderMailer.account_auto_created(invoice.user, message).deliver_now
        end
      rescue
      end
    end

    res
  end

  # Mass Pay is used for making payment to translators
  # We are looking here for unique_ids to update status
  def process_mass_pay(params_dict)
    # look for unique IDs. They are the mass_payment_receipt numbers
    payment_status = params_dict['payment_status']
    params_dict.each do |key, _value|
      next unless key[0..9] == 'unique_id_'
      idx = key[10..-1].to_i

      logger.info "--------- checking unique_id field: #{key}"

      # make sure the index is valid
      next unless idx > 0
      # now, find the rest of the transaction's parameters
      unique_id = params_dict["unique_id_#{idx}"].to_i
      status = TXN_PAYMENT_STATUS[params_dict["status_#{idx}"]]
      fee = params_dict["mc_fee_#{idx}"].to_f
      txn_id = params_dict["masspay_txn_id_#{idx}"]

      logger.info " --> Got idx: #{idx}, status: #{status}, fee: #{fee}, txn_id: #{txn_id}"

      # verify that all parameters were recovered correctly
      next unless status && fee && txn_id

      # get the receipt
      begin
        receipt = MassPaymentReceipt.find(unique_id)
        logger.info " --> Got receipt: #{receipt.id}. Status: #{receipt.status}"
      rescue ActiveRecord::RecordNotFound
        logger.info " +++> can't find receipt: #{unique_id}"
        receipt = nil
      end

      # make sure the receipt was recovered correctly and that the status needs update
      skip = false
      StaleObjHandler.retry do
        skip = receipt && (receipt.status == status)
      end
      next if skip

      logger.info ' --> Updating receipt'
      receipt.status = status
      receipt.fee = fee
      receipt.txn = txn_id

      # check if this completes the transaction, if so, mark the transaction
      if status == TXN_COMPLETED
        mark_transaction_as_complete(receipt.money_transaction)
        logger.info ' --> Completed money transaction'
      # Completed, Failed, Reversed, or Unclaimed
      elsif (status == TXN_REVERSED) || (status == TXN_FAILED) || ((status == TXN_UNCLAIMED) && (payment_status == 'Completed'))
        reverse_money_transaction(receipt.money_transaction, TRANSFER_REVERSAL_OF_PAYMENT_TO_EXTERNAL_ACCOUNT)
        logger.info ' --> Reversed money transaction'
      end
      receipt.save!
      receipt.money_transaction.unlock
    end
  end

  def validate_invoice_details(invoices_ids, mc_gross, tax, mc_currency, business, payment_status)
    @error_codes = []

    @invoices = []
    invoices_ids.each do |invoice_id|
      unless setup_invoice_for_user(invoice_id)
        @error_codes << [Invoice::INVOICE_NOT_FOUND, "Invoice: #{invoice_id}"]
        return nil
      end
      @invoices << @invoice # set inside setup_invoice_for_user
    end

    @invoices.each do |_invoice|
      if business != Figaro.env.PAYPAL_BUSINESS_EMAIL
        @error_codes << [Invoice::WRONG_BUSINESS_EMAIL_ADDRESS, "Expected: #{Figaro.env.PAYPAL_BUSINESS_EMAIL}, Got: #{business}"]
      end
      unless TXN_PAYMENT_STATUS.key?(payment_status)
        @error_codes << [Invoice::UNKNOWN_PAYMENT_STATUS, "Got: #{payment_status}"]
      end
      if mc_currency != @invoice.currency.name
        @error_codes << [Invoice::WRONG_CURRENCY, "Expected: #{@invoice.currency.name}, Got: #{mc_currency}"]
      end
      unless equal_f?(tax, @invoice.tax_amount)
        @error_codes << [Invoice::WRONG_AMOUNT, "Tax Expected: #{@invoice.tax_amount}, Got: #{tax}"]
      end
    end

    invoices_gross_amount = @invoices.inject(0) { |memo, inv| memo + inv.gross_amount } + tax
    unless equal_f?(mc_gross, invoices_gross_amount)
      @error_codes << [Invoice::WRONG_AMOUNT, "Expected: #{invoices_gross_amount}, Got: #{mc_gross}"]
    end

    # @ToDo if this has an error should send a mail to developer o store in a logs table

    @error_codes.empty?

  end

  def equal_f?(f1, f2)
    f1 = BigDecimal.new(f1.to_s)
    f2 = BigDecimal.new(f2.to_s)

    (f1 - f2).abs <= 0.01
  end
  private :equal_f?

  def abort_purchase(tx, invoice_id, reasons)
    reason_int = 0
    logger.info "PAYPAL PURCHASE #{tx} FOR INVOICE #{invoice_id} ABORTED:"
    reasons.each do |reason|
      reason_int += reason[0]
      logger.info "------ #{Invoice::VALIDATOR_ERROR_DESCRIPTION[reason[0]]}: #{reason[1]}"
    end
    problem_deposit = ProblemDeposit.new(reason: reason_int,
                                         txn: tx,
                                         invoice_id: invoice_id,
                                         status: ProblemDeposit::CREATED)
    problem_deposit.save!
    @errors = reasons
    logger.info "errors for txn #{problem_deposit.txn}: #{@errors}"

    render(action: :payment_not_completed)
  end

  def find_or_create_external_account(user, find_attributes, create_attributes)
    attempt = 1
    ok = false
    while !ok && (attempt < 10)
      external_account = ExternalAccount.where(find_attributes).first
      if external_account
        # if (user[:type] != 'TemporaryUser') && (external_account.normal_user != user)
        # logger.info "external account already belongs to someone else: #{external_account.normal_user.class}.#{external_account.normal_user.id}"
        # return nil
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

  def verify_account_ownership

    @account = MoneyAccount.find(params[:id])
    return false if @account.normal_user != @user
  rescue
    return false

  end

  def verify_invoice_ownership
    unless setup_invoice_for_user(params[:id])
      flash[:notice] = _('The selected invoice cannot be located')
      redirect_to action: :invoices
    end
  end

  def verify_no_manager
    if @orig_user && !@orig_user.has_supporter_privileges?
      set_err('Reviewers cannot access this page')
      false
    end
  end

  def setup_invoice_for_user(invoice_id)
    begin
      invoice = Invoice.find(invoice_id)
      if !@user || (invoice.user == @user) || @user.has_admin_privileges?
        @invoice = invoice
        return true
      end
    rescue
    end
    false
  end

  # ----------- complete instant translation project setup ------------
  def complete_instant_translation_project(invoice, external_account)
    complete_invoice_from_unreg(invoice, external_account) do |temp_user, user, account|
      temp_user.web_messages.each do |web_message|
        web_message.user = user
        web_message.owner = user
        web_message.money_account = account
        web_message.save!
      end
    end
  end

  def complete_invoice_from_unreg(invoice, external_account)
    curtime = Time.now
    temp_user = invoice.user
    temp_user_id = invoice.user_id

    user = User.where('email=?', external_account.identifier).first
    unless user
      # find an available nickname
      nickname_base = external_account.fname + external_account.lname
      idx = 1
      cont = true
      while cont
        nickname = "#{nickname_base}#{idx}"
        if User.where('nickname=?', nickname).first
          idx += 1
        else
          cont = false
        end
      end

      user = Client.create!(email: external_account.identifier,
                            fname: external_account.fname,
                            lname: external_account.lname,
                            userstatus: USER_STATUS_REGISTERED,
                            password: Digest::MD5.hexdigest(curtime.to_s)[0..6],
                            nickname: nickname,
                            notifications: NEWSLETTER_NOTIFICATION,
                            signup_date: curtime)

    end

    external_account.update_attributes!(normal_user: user)
    invoice.user = user
    invoice.save!

    # create user account
    # create money transaction and deposit the money to the user's account
    # set user account to web_messages without account
    account = user.find_or_create_account(invoice.currency_id)

    yield(temp_user, user, account)
    MoneyTransactionProcessor.transfer_money(external_account, account, invoice.gross_amount, invoice.currency_id, TRANSFER_DEPOSIT_FROM_EXTERNAL_ACCOUNT)

    temp_user = TemporaryUser.where('id=?', temp_user_id).first
    if temp_user
      temp_user.reload
      temp_user.destroy
    end
  end

  def migrate_temporary_user_to_normal(temp_user, external_account)
    curtime = Time.now
    temp_user_id = temp_user.id

    user = User.where('email=?', external_account.identifier).first
    unless user
      user = User.create_new(external_account.fname, external_account.lname, external_account.identifier)
    end

    # move the ownership over the external account
    external_account.normal_user = user
    external_account.save

    user.transfer_from_other_user(temp_user)

  end

  def set_time_range
    if params[:range]
      begin
        @end_time = Date.civil(params[:range][:"end_time(1i)"].to_i, params[:range][:"end_time(2i)"].to_i, params[:range][:"end_time(3i)"].to_i).end_of_day
        @start_time = Date.civil(params[:range][:"start_time(1i)"].to_i, params[:range][:"start_time(2i)"].to_i, params[:range][:"start_time(3i)"].to_i)
      rescue
        @error = 'Invalid date'
      end
    end
    @end_time = Time.now unless @end_time
    @start_time = Time.now.beginning_of_year unless @start_time
  end

  def view_finances
    unless @user.can_view_finance?
      set_err _("You don't have permission for that.")
      nil
    end
  end

  def set_account
    begin
      @account = MoneyAccount.find(params[:id].to_i)
    rescue ActiveRecord::RecordNotFound
      @account = nil
    end

    if !@account || (!@user.has_admin_privileges? && ![@user, @user.master_account].include?(@account.normal_user))
      set_err('Account not found, or is not yours.')
      return
    end

    if @user.alias? && !@user.alias_profile.financial_view
      set_err("You don't have permission to do that")
      return
    end

  end
end
