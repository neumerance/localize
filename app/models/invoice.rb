#   status:
#     1 = Created
#     2 = Paid
#     5 = Expire
#     7 = Waiting for payment to complete
# 	payment_processor
# 		EXTERNAL_ACCOUNT_PAYPAL = 1
# 		EXTERNAL_ACCOUNT_CREDITCARD = 2
# 		EXTERNAL_ACCOUNT_CHECK = 3
# 		EXTERNAL_ACCOUNT_BANK_TRANSFER = 4
# 		EXTERNAL_ACCOUNT_GOOGLE_CHECKOUT = 5
# 		EXTERNAL_ACCOUNT_2CHECKOUT = 6
class Invoice < ApplicationRecord
  belongs_to :user
  belongs_to :address
  belongs_to :currency

  has_many :money_transactions, as: :owner, dependent: :destroy
  has_many :reminders, as: :owner, dependent: :destroy
  # Used to determine which CmsRequests were paid for in WPML translation
  # projects.
  has_many :cms_requests, dependent: :nullify

  belongs_to :source, polymorphic: true

  validates_presence_of :currency, :gross_amount

  MASS_PAY_FOLDER = "#{Rails.root}/private/#{Rails.env}/mass_pay_files".freeze

  # Invoice kinds
  PAYMENT_FOR_TRANSLATION_WORK = 1
  DEPOSIT_TO_ACCOUNT = 2
  STAND_ALONE_WITHDRAWAL = 3
  STAND_ALONE_DEPOSIT = 4
  INSTANT_TRANSLATION_PAYMENT = 5
  PAYMENT_FOR_KEYWORDS = 6

  # status for invoice
  STATUS_TEXT = {
    TXN_CREATED => N_('Created'),
    TXN_PENDING => N_('Waiting for payment to complete'),
    TXN_COMPLETED => N_('Paid'),
    TXN_EXPIRED => N_('Expired')
  }.freeze

  PAYMENT_PROCESSOR_TEXT = {
    EXTERNAL_ACCOUNT_PAYPAL => 'Paypal',
    EXTERNAL_ACCOUNT_CREDITCARD => 'Credit Card',
    EXTERNAL_ACCOUNT_CHECK => 'Check',
    EXTERNAL_ACCOUNT_BANK_TRANSFER => 'Bank Transfer',
    EXTERNAL_ACCOUNT_GOOGLE_CHECKOUT => 'Google Checkout',
    EXTERNAL_ACCOUNT_2CHECKOUT => '2 Checkout'

  }.freeze

  # validation error codes
  INVOICE_NOT_FOUND = 1
  WRONG_BUSINESS_EMAIL_ADDRESS = 2
  WRONG_CURRENCY = 4
  WRONG_AMOUNT = 8
  UNKNOWN_PAYMENT_STATUS = 16
  BAD_CALL = 32
  CANT_UPDATE_INVOICE = 64
  CANT_FIND_EXTERNAL_ACCOUNT = 128

  VALIDATOR_ERROR_DESCRIPTION = {
    INVOICE_NOT_FOUND => N_('The invoice for this payment cannot be located.'),
    WRONG_BUSINESS_EMAIL_ADDRESS => N_('The recipient for this payment in unknown.'),
    WRONG_CURRENCY => N_("The currency for this payment doesn't match our invoice."),
    WRONG_AMOUNT => N_("The amount paid doesn't match our invoice."),
    UNKNOWN_PAYMENT_STATUS => N_('The status of this payment cannot be determined.'),
    BAD_CALL => N_('Your payment did not go through our automated system.'),
    CANT_UPDATE_INVOICE => N_("Can't update invoice"),
    CANT_FIND_EXTERNAL_ACCOUNT => N_("Can't find external account")
  }.freeze

  has_one :lock, as: :object, dependent: :destroy
  include Lockable

  def display_money_transactions
    if money_transactions.length <= 1 + money_transactions.map(&:target_account).map(&:class).map(&:to_s).count('TaxAccount') # fix for icldev-781
      money_transactions
    else
      res = []
      money_transactions.each do |money_transaction|
        if [BidAccount, ResourceLanguageAccount, TaxAccount, KeywordAccount].include?(money_transaction.target_account.class)
          res << money_transaction
        end
      end
      res
    end
  end

  # this method was added to fix #icldev-789
  def filtered_money_transactions
    res = []
    money_transactions.each do |money_transaction|
      if [UserAccount, TaxAccount].include?(money_transaction.target_account.class)
        res << money_transaction
      end
    end
    res
  end

  def description(user)
    begin
      if kind == INSTANT_TRANSLATION_PAYMENT
        res = _('Payment for Instant Text Translation')
      elsif money_transactions.empty?
        res = _('Deposit to your ICanLocalize account for translation work')
      elsif kind == PAYMENT_FOR_TRANSLATION_WORK
        descriptions = []
        work = {}
        for transaction in money_transactions
          if transaction.target_account.class == BidAccount
            project = transaction.target_account.bid.chat.revision.project.name
            language = transaction.target_account.bid.revision_language.language.name
            if work.key?(project)
              work[project] << language
            else
              work[project] = [language]
            end
          elsif transaction.target_account.class == UserAccount
            to_add = if transaction.target_account.normal_user.id == user.id
                       _('Deposit to your ICanLocalize account  for translation work')
                     else
                       _('Deposit to the ICanLocalize account of %s') % transaction.target_account.normal_user.full_name
                     end
            descriptions << to_add
          end
        end
        descriptions = [] unless work.empty?
        work.each { |k, v| descriptions << _('Translation of %s to %s') % [k, v.join(', ')] }
        res = if !descriptions.empty?
                descriptions.join('; ')
              else
                _('Payment for translation work')
              end
      elsif kind == DEPOSIT_TO_ACCOUNT
        res = _('Deposit to account')
      elsif kind == STAND_ALONE_DEPOSIT
        res = _('Deposit to an ICanLocalize account')
      elsif kind == STAND_ALONE_WITHDRAWAL
        res = _('Withdrawal from ICanLocalize account')
      elsif kind == PAYMENT_FOR_KEYWORDS
        res = ''
        money_transactions.each do |tr|
          next unless tr.target_account.is_a? KeywordAccount
          project = tr.target_account.keyword_project.owner.project_name
          language = tr.target_account.keyword_project.owner.language.name
          number = tr.target_account.keyword_project.keyword_package.keywords_number
          res += _('Payment for keyword package of %s words on project %s to language %s<br>') % [number, project, language]
        end
      end
    rescue
      res = 'Problem creating description for invoice #%d' % id
    end
    res
  end

  def create_reminder
    conds = ["owner_type IN ('Bid', 'Invoice') AND owner_id= ? AND event= ?", id, EVENT_INVOICE_DUE]
    reminder = user.reminders.where(conds).first

    unless reminder
      reminder = Reminder.new(event: EVENT_INVOICE_DUE)
      reminder.normal_user = user
      reminder.owner = self
      reminder.save!
    end
  end

  def default_company
    if user.company.blank?
      _('Name: %s') % user.full_real_name + "\n" + _('Email: %s') % user.email
    else
      user.company
    end
  end

  def self.delete_previous_duplicate(user, source, kind = false)
    # TODO: check with alias
    conditions = {
      user_id: user.id,
      status: TXN_CREATED
    }

    if source
      conditions[:source_type] = source.class.base_class.name
      conditions[:source_id] = source.id
    end

    conditions[:kind] = kind if kind

    invoices = Invoice.where(conditions)

    invoices.each do |invoice|
      Rails.logger.info "Deleting previous invoice: #{invoice} (marking as expired)"
      invoice.update_attribute :status, TXN_EXPIRED
      invoice.reminders.delete_all
      # invoice.money_transactions.delete_all
      # invoice.delete
    end
  end

  # this is used when customer pay with paypal a bidding project (revision)
  # if user pay with balance TransactionProcessor#create_invoice_for_bids is used
  def self.create_for_bids(user_money_account, user, revision)
    curtime = Time.now

    # Check if we already have a PENDING invoice for this.
    Invoice.delete_previous_duplicate user, revision, Invoice::PAYMENT_FOR_TRANSLATION_WORK

    # 1) Create the invoice
    transfer_total = revision.pending_translation_and_review_cost.ceil_money

    #           ===== Use available balance ======
    # This is tricky to implement because we are creating the
    # transfers to bids here, and calculate the total amount
    # using the available balance lead to wrong values on invoices items,
    # and the possibility to use multiple times the same available balance on many invoices.
    #
    # This is however used in text resources.
    # Uncomment code in _payment_table.rhtml to calculate on table automatically.
    #
    #
    # transfer_total = transfer_total - user_money_account.balance

    invoice = Invoice.new(
      kind: Invoice::PAYMENT_FOR_TRANSLATION_WORK,
      payment_processor: EXTERNAL_ACCOUNT_PAYPAL,
      currency_id: DEFAULT_CURRENCY_ID,
      gross_amount: transfer_total,
      status: TXN_CREATED,
      create_time: curtime,
      modify_time: curtime,
      source: revision
    )
    invoice.user = user
    invoice.set_tax_information
    invoice.save!

    invoice.create_reminder

    # 2) Create a transfer of the total amount to the client's account
    money_transaction = MoneyTransaction.new(
      amount: transfer_total,
      currency_id: DEFAULT_CURRENCY_ID,
      chgtime: curtime,
      status: TRANSFER_PENDING,
      operation_code: TRANSFER_DEPOSIT_FROM_EXTERNAL_ACCOUNT
    )
    money_transaction.owner = invoice
    money_transaction.target_account = user_money_account
    money_transaction.save!

    # 3) Create a transfer for each of the bids to the bid account
    bids_pending_revision = revision.pending_managed_works.map { |mw| mw.owner.selected_bid }
    bids = revision.pending_bids | bids_pending_revision
    bids.each do |bid|
      bid.revision_language.delete_reminders(EVENT_NEW_BID)
      bid.revision_language.delete_reminders(EVENT_BID_WAITING_PAYMENT)

      transfer_amount = bid.pending_cost.ceil_money

      money_transaction = MoneyTransaction.new(
        amount: transfer_amount,
        currency_id: DEFAULT_CURRENCY_ID,
        chgtime: curtime,
        status: TRANSFER_PENDING,
        operation_code: TRANSFER_DEPOSIT_FROM_EXTERNAL_ACCOUNT
      )
      money_transaction.owner = invoice
      money_transaction.source_account = user_money_account
      money_transaction.target_account = bid.find_or_create_account
      money_transaction.save!
    end

    # 4) Create a transfer for tax
    money_transaction = MoneyTransaction.new(
      amount: invoice.tax_amount,
      currency_id: DEFAULT_CURRENCY_ID,
      chgtime: curtime,
      status: TRANSFER_PENDING,
      operation_code: TRANSFER_TAX_RATE
    )
    money_transaction.owner = invoice
    money_transaction.target_account = TaxAccount.find_or_create
    money_transaction.save!

    invoice
  end

  def fee
    if money_transactions.count == 1
      money_transactions.first.fee.to_f
    else
      money_transactions.find_all { |mt| mt.target_account.is_a? UserAccount }.try(:first).try(:fee).to_f
    end
  end

  def set_tax_information
    raise	'User must be set to set tax information' unless user
    raise	'gross_amount must be set to set tax information' unless gross_amount

    if user.has_to_pay_taxes?
      self.tax_amount = user.calculate_tax(gross_amount)
      self.tax_rate        = user.tax_rate
      self.tax_country_id  = user.country_id
      self.vat_number      = user.full_vat_number
    end
  end

  def total_amount
    gross_amount + tax_amount
  end

end
