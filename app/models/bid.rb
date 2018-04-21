#   status:
#     BID_GIVEN = 1     # translator has given a bid
#     BID_ACCEPTED = 2    # bid was accepted
#     BID_COMPLETED = 3   # client accepted work on that bid, and it's now completed
#     BID_WAITING_FOR_PAYMENT = 4 # client started a payment for this bid, but the payment is not complete
#     BID_REFUSED = 10    # bid was refused
#     BID_CANCELED = 11;    # bid has been canceled
#     BID_TERMINATED = 12;  # work was terminated via mutual arbitation process
#     BID_DECLARED_DONE = 13  # the translator declares the work as complete
class Bid < ApplicationRecord
  include TransactionProcessor

  has_one :revision, through: :revision_language
  has_one :translator, through: :chat
  has_one :account, foreign_key: :owner_id, class_name: 'BidAccount', dependent: :destroy
  has_one :arbitration, as: :object, dependent: :destroy
  has_one :managed_work, through: :revision_language

  belongs_to :currency
  belongs_to :chat
  belongs_to :revision_language

  has_many :reminders, as: :owner, dependent: :destroy

  BID_STATUS = {
    BID_GIVEN => N_('Bid given by translator'),
    BID_WAITING_FOR_PAYMENT => N_('Waiting for escrow deposit'),
    BID_ACCEPTED => N_('Bid was accepted'),
    BID_COMPLETED => N_('Work on bid has been completed'),
    BID_REFUSED => N_('Bid was refused'),
    BID_CANCELED => N_('Bid was cancelled'),
    BID_TERMINATED => N_('Bid was terminated in an arbitration process'),
    BID_DECLARED_DONE => N_('Translator declared the work as completed')
  }.freeze

  before_save :set_won
  validate :std_translator_amount_restrictions,
           :private_translator_amount_restrictions
  validates_uniqueness_of :chat_id, scope: :revision_language_id, message: 'You can only have one chat per project target language'

  def accepted?
    status == BID_ACCEPTED
  end

  def given?
    status == BID_GIVEN
  end

  def set_won
    return if @skip_set_won
    self.won = BID_WON_STATUS.include?(status) ? 1 : nil
    chat.revision.update_attributes(update_counter: chat.revision.update_counter + 1)
  end

  def private_translator_amount_restrictions
    if chat.translator.private_translator? && (amount != 0)
      errors.add(:amount, 'should be 0 for private translators')
    end
  end

  def no_amount_restrictions
    status == BID_REFUSED ||
      won ||
      chat.translator.private_translator? ||
      revision_language.revision.cms_request ||
      revision_language.revision.practice_project?
  end

  def pay_translator
    Logging.log(self, pay_translator: :started)
    from = account
    to = chat.translator.find_or_create_account(DEFAULT_CURRENCY_ID)
    amount = translator_payment
    MoneyTransactionProcessor.transfer_money(from, to, amount, DEFAULT_CURRENCY_ID, TRANSFER_PAYMENT_FROM_BID_ESCROW, FEE_RATE, revision.client.affiliate)
    Logging.log(self, pay_translator: :finished)
  end

  def pay_reviewer
    Logging.log(self, pay_reviewer: :started)
    from = account
    to = managed_work.translator.find_or_create_account(currency_id)
    amount = revision.reviewer_payment(self)
    MoneyTransactionProcessor.transfer_money(from, to, amount, DEFAULT_CURRENCY_ID, TRANSFER_PAYMENT_FROM_BID_ESCROW, FEE_RATE, revision.client.affiliate)
    Logging.log(self, pay_reviewer: :finished)
  end

  def create_reminder(who, event)
    reminder = reminders.find_by(normal_user_id: who, event: event)
    unless reminder
      reminder = Reminder.new(event: event)
      reminder.normal_user = who
      reminders << reminder
      reminder.save!
    end
  end

  def delete_reminders(who)
    reminders.where(normal_user_id: who.id).find_each(&:destroy)
  end

  def delete_all_reminders
    delete_reminders(revision.client)
    delete_reminders(translator)

    chat.delete_reminders(translator)
    chat.delete_reminders(revision.client)

    # before refact, was doing this: revision_language.delete_reminders(EVENT_NEW_BID)
    revision_language.reminders.each(&:destroy)
  end

  def complete?
    status == BID_COMPLETED
  end

  def complete!
    update_attribute(:status, BID_COMPLETED)
  end

  def finalize
    return if complete? && (not managed_work.waiting_for_payment?)

    ActiveRecord::Base.transaction do
      unless complete?
        pay_translator
        complete!
      end

      if managed_work.try(:waiting_for_payment?)
        pay_reviewer
        managed_work.update_attribute :translation_status, MANAGED_WORK_COMPLETE
      end
    end

    if revision.practice_project? && (not chat.translator.qualified?)
      chat.translator.qualify
    end

    unless from_cms?
      delete_all_reminders
      create_reminder(chat.translator, EVENT_BID_COMPLETED)
      if chat.translator.can_receive_emails?
        ReminderMailer.bid_finalized(chat.translator, self).deliver_now
      end
    end
  end

  def can_finalize_review?
    return false if managed_work.complete?
    # FIXME: Somewhere in the, when the reviewer take a project, it is not set correctly as reviewer.
    # Fixing this here since can't find where.
    if managed_work.waiting_for_reviewer? && managed_work.translator
      managed_work.update_attribute :translation_status, MANAGED_WORK_REVIEWING
    end
    managed_work && managed_work.active? && managed_work.reviewing?
  end

  def finalize_review
    return false unless can_finalize_review?

    # Save status
    managed_work.update_attributes(translation_status: MANAGED_WORK_WAITING_FOR_PAYMENT)

    if from_cms?
      finalize
      if revision.client.can_receive_emails?
        revision.cms_request.update(completed_at: Time.now)
      end
    else
      # Create reminder
      unless revision.cms_request
        reminder = Reminder.new(event: EVENT_WORK_DONE, normal_user_id: revision.client.id)
        reminder.owner = revision_language
        reminder.save
      end

      # Send e-mails
      if revision.client.can_receive_emails?
        ReminderMailer.review_completed_for_project(revision.client, managed_work.translator, chat, [revision_language]).deliver_now
      end
    end
  end

  def reviewer_payment
    revision.reviewer_payment(self)
  end

  def translator_payment
    revision.translator_payment(self)
  end

  def cancel
    self.status = BID_CANCELED
    save!
  end

  def cancel_review
    return unless managed_work && @project

    managed_work.cancel

    unless revision.cms_request
      reminder = Reminder.new(event: EVENT_WORK_DONE, normal_user_id: @project.client_id)
      reminder.owner = revision_language
      reminder.save!
    end
  end

  def std_translator_amount_restrictions
    unless no_amount_restrictions
      if revision_language.revision.ta? && (!amount || amount < revision_language.revision.client.minimum_bid_amount)
        errors.add(:amount, 'must be greater than %.2f USD per word' % revision_language.revision.client.minimum_bid_amount)
      end

      minimum_amount = (revision_language.revision.client.minimum_bid_amount * revision_language.revision.word_count.to_i).to_s.to_d
      if !revision_language.revision.ta? && (!amount || amount < minimum_amount)
        errors.add(:amount, 'should be no less than %s per word. Please note that the bid in this project is for the entire work, not per word.' % revision_language.revision.client.minimum_bid_amount)
      end

      if revision_language.revision.max_bid && (revision_language.revision.max_bid > 0) && (amount > revision_language.revision.max_bid)
        errors.add(:amount, 'should be no more than %s USD' % revision_language.revision.max_bid)
      end
    end
    if chat.translator == revision_language.try(:managed_work).try(:translator)
      errors.add(:amount, "The assigned translator can't be the reviewer at the same time.")
    end
  end

  def auto_accept?
    revision.auto_accept_amount &&
      revision.auto_accept_amount > 0 &&
      (amount <= revision.auto_accept_amount) &&
      (revision_language.missing_amount_for_auto_accept == 0) &&
      revision_language.selected_bid.nil?
  end

  def auto_accept
    from_account = revision.project.client.find_or_create_account(DEFAULT_CURRENCY_ID)
    transfer_amount = revision.cost_for_bid(self).ceil_money

    MoneyTransactionProcessor.transfer_money(from_account, find_or_create_account, transfer_amount, currency_id, TRANSFER_DEPOSIT_TO_BID_ESCROW)
    accept

    managed_work.activate if managed_work && managed_work.enabled?
    if chat.revision.project.manager.can_receive_emails?
      ReminderMailer.auto_accepted_bid(chat.revision.project.manager, chat.translator, self).deliver_now
    end
  end

  def accept
    prev_status = status

    self.status = BID_ACCEPTED
    self.expiration_time = Time.now + (DAY_IN_SECONDS * chat.revision.project_completion_duration)
    self.accept_time = Time.now

    save!
    set_acceptance_reminders
    send_acceptance_emails(prev_status)
  end

  def wait_payment
    find_or_create_account
    self.status = BID_WAITING_FOR_PAYMENT
    save!
  end

  def waiting_for_payment?
    status == BID_WAITING_FOR_PAYMENT
  end

  def total_cost
    revision.cost_for_bid(self)
  end

  def blocked?
    [BID_REFUSED, BID_CANCELED, BID_TERMINATED].include? status
  end

  def pending_cost
    total = 0
    total += translator_payment if waiting_for_payment?
    total += reviewer_payment if managed_work.pending_payment?
    total
  end

  def transfer_escrow
    from = revision.client.money_accounts.first
    to = find_or_create_account
    amount = total_cost
    logger.info "==========Transfering #{amount}"
    MoneyTransactionProcessor.transfer_money(from, to, amount, DEFAULT_CURRENCY_ID, TRANSFER_DEPOSIT_TO_BID_ESCROW)
  end

  def transfer_translation_escrow
    from = revision.client.money_accounts.first
    to = find_or_create_account
    MoneyTransactionProcessor.transfer_money(from, to, translator_payment.ceil_money, DEFAULT_CURRENCY_ID, TRANSFER_DEPOSIT_TO_BID_ESCROW)
  end

  def transfer_review_escrow
    from = revision.client.money_account
    to = find_or_create_account
    MoneyTransactionProcessor.transfer_money(from, to, reviewer_payment.ceil_money, DEFAULT_CURRENCY_ID, TRANSFER_DEPOSIT_TO_BID_ESCROW)
  end

  def return_unused_escrow_amount
    to = revision.client.money_account
    from = find_or_create_account
    MoneyTransactionProcessor.transfer_money(from, to, from.balance, DEFAULT_CURRENCY_ID, TRANSFER_REFUND_FROM_BID_ESCROW)
  end

  # Email to send when complete: ReminderMailer.bid_finalized(chat.translator, self).deliver_now
  def send_acceptance_emails(prev_status)
    if chat.translator.can_receive_emails?
      if !chat.revision.cms_request
        if chat.translator.private_translator?
          ReminderMailer.project_assigned(chat.translator, self).deliver_now
        else
          ReminderMailer.bid_accepted(chat.translator, self).deliver_now
        end
      elsif chat.revision.cms_request && (prev_status == BID_WAITING_FOR_PAYMENT)
        ReminderMailer.work_can_resume(chat.translator, self).deliver_now
      end
    end

    other_bids = revision_language.bids.where(status: BID_GIVEN)
    other_bids.each do |other_bid|
      if other_bid.translator.can_receive_emails?
        ReminderMailer.not_won_message(other_bid).deliver_now
      end
    end
  end

  # Reminders created when the bid is complete
  def set_acceptance_reminders
    case status
    when BID_ACCEPTED
      event = EVENT_BID_ACCEPTED
      revision_language.delete_reminders(EVENT_NEW_BID)
    when BID_COMPLETED
      event = EVENT_BID_COMPLETED
    else
      return
    end

    reminder = Reminder.new(event: event)
    reminder.normal_user = chat.translator
    reminders << reminder
    reminder.save!
  end

  def is_assigned
    won == 1
  end

  def print_amount(factor = 1)
    "#{amount.ceil_money * factor} ".html_safe + currency.disp_name.html_safe + ' ' + chat.revision.payment_units
  end

  def days_to_complete=(num)
    self.expiration_time = accept_time + num * DAY_IN_SECONDS
  end

  def days_to_complete
    Integer((expiration_time - accept_time) / DAY_IN_SECONDS)
  end

  def has_accepted_details
    BID_ACCEPTED_STATUSES.include?(status)
  end

  def has_expiration_details
    (status == BID_ACCEPTED) || (status == BID_DECLARED_DONE)
  end

  def can_arbitrate
    !arbitration && [BID_ACCEPTED, BID_DECLARED_DONE, BID_WAITING_FOR_PAYMENT].include?(status)
  end

  def find_or_create_account
    # if this bid doesn't yet have an account in this currency, let's create it now
    if account.nil?
      account = BidAccount.new(currency_id: currency_id)
      account.bid = self
      account.save!
      return account
    end
    self.account
  end

  def from_cms?
    not chat.revision.cms_request.nil?
  end

  def declare_done
    if from_cms?
      finalize
      reminders.destroy_all
      revision_language.reminders.destroy_all
    else
      if revision.project.client.can_receive_emails?
        ReminderMailer.work_complete(revision.project.client, self, chat.translator, managed_work && managed_work.translator).deliver_now
      end
      update_attributes!(status: BID_DECLARED_DONE)
    end

    if managed_work&.active? && managed_work&.translator
      if managed_work.translator.can_receive_emails?
        ReminderMailer.project_for_review(self).deliver_now
      end
      managed_work.update_attributes(translation_status: MANAGED_WORK_REVIEWING)
    else
      managed_work.update_attributes(translation_status: MANAGED_WORK_WAITING_FOR_REVIEWER)
      unless from_cms?
        reminder = Reminder.new(event: EVENT_WORK_DONE, normal_user_id: revision.project.client_id)
        reminder.owner = revision_language
        reminder.save!
      end
    end
  end

  def unset_won
    @skip_set_won = true
    self.won = nil
    save
  end

  def start_review(translator = nil)
    # If the revision is a part of a Website Translation project, update the
    # cms_request.review_enabled attribute.
    revision.cms_request&.update(review_enabled: true)

    unless revision_language.managed_work
      revision_language.managed_work = ManagedWork.new(active: MANAGED_WORK_INACTIVE,
                                                       translation_status: MANAGED_WORK_CREATED,
                                                       from_language_id: revision.language_id,
                                                       to_language_id: revision_language.language_id)
      revision_language.managed_work.client = revision.client
      revision_language.managed_work.owner = revision_language
      revision_language.managed_work.notified = 0
      revision_language.managed_work.save!
    end

    revision_language.managed_work.active = MANAGED_WORK_ACTIVE
    revision_language.managed_work.translator = translator
    revision_language.managed_work.translation_status = if revision_language.managed_work.translator
                                                          MANAGED_WORK_REVIEWING
                                                        else
                                                          MANAGED_WORK_WAITING_FOR_REVIEWER
                                                        end
    revision_language.managed_work.save!
  end

  def update_bid_to_accepted
    ok_bid = true
    ok_review = true

    # On CMS requests, given bids are when translator clicks on "assign to me" and
    # client has enough money.
    if waiting_for_payment? || (revision.cms_request && given?)
      ok_bid = accepted?
      attempt = 1
      while (attempt < MAX_RETRY_ATTEMPTS) && !ok_bid
        ok_bid = accept
        attempt += 1
      end
    end

    if managed_work.pending_payment?
      ok_review = managed_work.active?
      attempt = 1
      while (attempt < MAX_RETRY_ATTEMPTS) && !ok_review
        ok_review = managed_work.activate
        attempt += 1
      end
    end

    ok_bid && ok_review
  end

  # this is called when translation for a cms_requests is marked as complete in WebTA
  def webta_declare_done(user_id, cms)
    return translation_completed_without_review(cms) unless managed_work.active?
    return translation_completed(cms) unless user_id == managed_work.translator_id
    return 'Review is already completed' if managed_work.complete?

    if self.status == BID_DECLARED_DONE &&
       managed_work.translation_status == MANAGED_WORK_REVIEWING

      return review_completed_with_open_issues(cms) if cms.mrk_issues.open_issues.present?
      review_completed(cms)
    end
  end

  private

  def review_completed(cms)
    cms.complete!
    managed_work.update_attribute(:translation_status, MANAGED_WORK_WAITING_FOR_PAYMENT) unless managed_work.complete?
    complete!
    ActiveRecord::Base.transaction do
      unless managed_work.complete?
        pay_translator
        pay_reviewer
        managed_work.complete!
      end

      cms.add_translated_xliff
      cms.update_tm
    end
    notify_tp_for_translation_complete(cms)
    'Review completed'
  end

  def translation_completed(cms)
    translation_status = managed_work.translator ? MANAGED_WORK_REVIEWING : MANAGED_WORK_WAITING_FOR_REVIEWER
    managed_work.update_attributes(translation_status: translation_status)
    update_attribute(:status, BID_DECLARED_DONE)
    cms.update_attribute(:status, CMS_REQUEST_TRANSLATED)
    cms.cms_target_language.update_attribute(:status, CMS_TARGET_LANGUAGE_DONE)
    notify_cms_reviewer(cms)
    'Translation completed'
  end

  def notify_cms_reviewer(cms)
    reviewer = cms.revision&.revision_languages&.take&.managed_work&.translator
    ReminderMailer.cms_ready_for_review(reviewer, cms).deliver_now if reviewer.present?
  end

  def translation_completed_without_review(cms)
    ActiveRecord::Base.transaction do
      unless complete?
        pay_translator
        complete!
        cms.cms_target_language.update!(status: CMS_TARGET_LANGUAGE_DONE)
        cms.complete!
      end

      cms.add_translated_xliff
      cms.update_tm
    end
    notify_tp_for_translation_complete(cms)
    'Translation completed'
  end

  def review_completed_with_open_issues(cms)
    cms.update_attribute(:status, CMS_REQUEST_RELEASED_TO_TRANSLATORS)
    managed_work.update_attribute(:translation_status, MANAGED_WORK_CREATED)
    update_attribute(:status, BID_ACCEPTED)
    if chat.translator.can_receive_emails?
      ReminderMailer.notify_review_completed_with_open_issues(chat.translator, managed_work.translator, revision_language, cms).deliver_now
    end

    'Review completed with open issues for translator'
  end

  def notify_tp_for_translation_complete(cms)
    Rails.logger.info cms.deliver
  rescue TranslationProxy::Notification::TPError => e
    Rails.logger.info 'ERROR DELIVERING JOB'
  end
end
