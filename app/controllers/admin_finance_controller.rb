class AdminFinanceController < ApplicationController
  include ::RootAccountCreate

  prepend_before_action :setup_user
  before_action :verify_admin
  layout :determine_layout

  def index
    @header = 'System finance summary'
    root_account = find_or_create_root_account(1)
    if params[:d].present?
      date = params[:d].to_date
      accounts = UserAccount.distinct.select('money_accounts.*').joins(:account_lines).where('chgtime BETWEEN ? AND ?', date.beginning_of_day, date.end_of_day)
      bid_accounts = BidAccount.distinct.select('money_accounts.*').joins(:account_lines).where('chgtime BETWEEN ? AND ?', date.beginning_of_day, date.end_of_day)
      account_line = root_account.account_lines.where('chgtime BETWEEN ? AND ?', date.beginning_of_day, date.end_of_day).order(chgtime: :desc).first
      @user_total = accounts.to_a.sum(&:balance) # needs to be convert to array, or else `DISTINCT` will not take effect
      @bids_total = bid_accounts.to_a.sum(&:balance)
      @fees_total = account_line&.balance || 0
    else
      @user_total = UserAccount.sum(:balance) || 0
      @bids_total = BidAccount.sum(:balance) || 0
      @fees_total = root_account.balance
    end
    @total = @user_total + @bids_total + @fees_total
  end

  def history
    @header = 'Transactions history'
    @account = find_or_create_root_account(1)

    @pager = ::Paginator.new(@account.account_lines.count, PER_PAGE) do |offset, per_page|
      @account.account_lines.limit(per_page).offset(offset).order('id DESC')
    end

    @account_lines = @pager.page(params[:page])
    @list_of_pages = []
    for idx in 1..@pager.number_of_pages
      @list_of_pages << idx
    end

  end

  def external_transactions
    @header = 'External transactions'
    # @transactions = MoneyTransaction.where("((source_account_type='ExternalAccount') OR (target_account_type='ExternalAccount')) AND (status=#{TRANSFER_COMPLETE})")

    money_transactions = MoneyTransaction.where("((source_account_type='ExternalAccount') OR (target_account_type='ExternalAccount')) AND (status=?)", TRANSFER_COMPLETE)

    @pager = ::Paginator.new(money_transactions.count, PER_PAGE) do |offset, per_page|
      money_transactions.limit(per_page).offset(offset).order('id DESC')
    end

    @transactions = @pager.page(params[:page])
    @list_of_pages = []
    for idx in 1..@pager.number_of_pages
      @list_of_pages << idx
    end

  end

  def paypal_transactions
    @header = 'PayPal transactions'

    @start_date = if params[:start_date]
                    Time.local(params[:start_date][:year].to_i, params[:start_date][:month].to_i, params[:start_date][:day].to_i)
                  else
                    Time.now - 1.day
                  end

    @end_date = if params[:end_date]
                  Time.local(params[:end_date][:year].to_i, params[:end_date][:month].to_i, params[:end_date][:day].to_i, 23, 59, 59)
                else
                  Time.now
                end

    logger.info "------------ @start_date: #{@start_date}, @end_date: #{@end_date}"

    invoices = Invoice.where(
      "(status=?)
      AND (payment_processor=?)
      AND (modify_time >= ?)
      AND (modify_time <= ?)",
      TXN_COMPLETED,
      EXTERNAL_ACCOUNT_PAYPAL,
      @start_date, @end_date
    )

    withdrawals = Withdrawal.where('submit_time >= ? AND submit_time <= ?', @start_date, @end_date)

    @all_events = {}
    invoices.each { |invoice| @all_events[invoice.modify_time.to_i] = invoice }
    withdrawals.each { |withdrawal| @all_events[withdrawal.submit_time.to_i] = withdrawal }

    unless params[:cvsformat].blank?
      csv_txt = paypal_transactions_csv(@all_events, @user)
      send_data(csv_txt,
                filename: "paypal_transactions_#{@start_date.strftime(DATE_FORMAT_STRING)}_to_#{@end_date.strftime(DATE_FORMAT_STRING)}.csv",
                type: 'text/plain',
                disposition: 'downloaded')
    end

  end

  def payments
    @header = 'Initiated mass payments'
    withdrawals = Withdrawal.limit(PER_PAGE).order('id DESC')
    @receipts = withdrawals.collect { |w| w.mass_payment_receipts.order('id DESC').first }
  end

  def payment
    receipt = MassPaymentReceipt.find(params[:id].to_i)
    fname = MassPayer.file_name_for_receipt(receipt, Invoice::MASS_PAY_FOLDER)
    if File.exist?(fname)
      send_file(fname)
    else
      flash[:notice] = 'File Not Found.'
      redirect_to url_for(action: :payments)
    end
  end

  def invoice_search
    @header = 'Seach for an invoice'
  end

  def countries_taxes
    @header = 'Taxes rates per country'
    @countries = if params[:group]
                   Country.where(tax_group: params[:group])
                 else
                   Country.all
                 end
  end

  def revenue_report
    @header = 'Revenue Report'
    params[:from] ||= Date.today - 1.month
    params[:to]   ||= Date.today + 1.day

    from = params[:from].to_time
    to = params[:to].to_time + 1.day

    @results = { software: 0, bidding: 0, cms: 0, instant_translation: 0, keyword: 0, ignored: 0, others: 0 }

    root_account = find_or_create_root_account(1)

    money_transactions = root_account.money_transactions.
                         where(
                           'money_transactions.chgtime > ? AND money_transactions.chgtime < ? AND status = ? AND fee_rate > 0',
                           from, to, TRANSFER_COMPLETE
                         )

    ignore_codes = [
      TRANSFER_PAYMENT_FOR_TA_RENTAL, # free for private translators
    ]
    codes_group = {
      bidding: [
        TRANSFER_PAYMENT_FROM_BID_ESCROW,
        TRANSFER_DEPOSIT_TO_BID_ESCROW # not sure about this
      ],
      software: [TRANSFER_PAYMENT_FROM_RESOURCE_REVIEW, TRANSFER_PAYMENT_FROM_RESOURCE_TRANSLATION],
      keyword: [TRANSFER_REUSE_KEYWORD, TRANSFER_PAYMENT_FROM_KEYWORD_LOCALIZATION]
    }

    pending = []
    ignored = []
    money_transactions.each do |mt|
      project_kind = :others
      ignore = false

      ignore = true if ignore_codes.include? mt.operation_code
      if mt.source_account.class == UserAccount && mt.target_account.class == UserAccount
        ignore = true if mt.source_account.user.class == Client && mt.target_account.user.class == Client
      end

      if ignore
        project_kind = :ignored
      else

        # Cms
        if mt.source_account.class == BidAccount && codes_group[:bidding].include?(mt.operation_code)
          revision = mt.source_account.bid.try(:chat).try(:revision)
          if revision
            project_kind = if revision.cms_request_id
                             :cms
                           else
                             # Bidding
                             :bidding
                           end
          end

        end

        # Software
        if (mt.owner_type == 'StringTranslation') && codes_group[:software].include?(mt.operation_code)
          project_kind = :software
        end

        # Instant Translations
        if (mt.owner_type == 'WebMessage') && (mt.operation_code == TRANSFER_PAYMENT_FOR_INSTANT_TRANSLATION)
          project_kind = :instant_translation
        end

        # Keyword
        # @ToDo this should calculate to the parent project?
        if codes_group[:keyword].include? mt.operation_code
          project_kind = :keyword
        end

      end

      @results[project_kind] += mt.fee

    end

  end

  private

  def verify_admin
    unless @user.has_admin_privileges?
      set_err('You are not authorized to view this')
      false
    end
  end

  def paypal_transactions_csv(all_events, user)
    res = "\"Date\",\"Description\",\"Net Amount\",\"Gross Amount\"\n\r"
    keys = all_events.keys().sort
    keys.each do |key|
      entry = all_events[key]
      if entry.class == Invoice
        date = entry.modify_time
        description = "Invoice.#{entry.id}: #{entry.description(user)}"
        net_amount = entry.net_amount
        gross_amount = entry.gross_amount
        col = '#E0FFE0'
      else
        total = 0
        fees = 0
        descriptions = []
        entry.mass_payment_receipts.each do |mass_payment_receipt|
          money_transaction = mass_payment_receipt.money_transaction
          total += money_transaction.amount
          fees += mass_payment_receipt.fee
          sa = money_transaction.source_account
          descriptions << "withdrawal from user account: #{sa.normal_user.full_name} (#{sa.normal_user[:type]})"
        end
        date = entry.submit_time
        description = "MassPay.#{entry.id}: " + descriptions.join(',')
        net_amount = -total
        gross_amount = -(total + fees)
        col = '#FFE0E0'
      end
      td_s = "style=\"background-color: #{col};\""
      res += "\"#{date.strftime(DATE_FORMAT_STRING)}\",\"#{description}\",\"#{net_amount}\",\"#{gross_amount}\"\n\r"
    end
    res
  end

end
