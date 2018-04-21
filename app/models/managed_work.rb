# Review of projects, only used when review is active
#   translation_status
#     MANAGED_WORK_CREATED = 0
#     MANAGED_WORK_REVIEWING = 1
#     MANAGED_WORK_COMPLETE = 2
#     MANAGED_WORK_WAITING_FOR_REVIEWER = 3
#     MANAGED_WORK_WAITING_FOR_PAYMENT = 4
#
#   active:
#     MANAGED_WORK_INACTIVE = 0
#     MANAGED_WORK_ACTIVE = 1
#     MANAGED_WORK_PENDING_PAYMENT = 2
#
#     WEBTA_REVIEW_DISABLE = 0
#     WEBTA_REVIEW_AND_CREATE_ISSUE = 1
#     WEBTA_REVIEW_AND_EDIT = 2
#
class ManagedWork < ApplicationRecord
  belongs_to :client
  belongs_to :translator, touch: true
  belongs_to :owner, polymorphic: true

  has_many :messages, as: :owner, dependent: :destroy
  has_one :support_ticket, as: :object

  has_many :reminders, as: :owner, dependent: :destroy

  belongs_to :from_language, class_name: 'Language', foreign_key: :from_language_id
  belongs_to :to_language, class_name: 'Language', foreign_key: :to_language_id
  belongs_to :resource_language, foreign_key: 'owner_id', touch: true
  has_one :translators_refused_project, as: :owner, dependent: :destroy

  # TODO: the following code after investigation is complete
  # BEGIN temporary code
  before_save :track_changes, if: -> { attribute_changed?(:active) }
  after_initialize :track_initialization, if: :new_record?
  def track_changes
    previous, current = attribute_change(:active)
    Rails.logger.info "managed_work #{self.id} owned by a '#{self.owner_type}' had its " \
                      "'active' attribute changed from '#{previous}' to '#{current}.\n" \
                      "The call stack that resulted in that change was:\n#{Logging.format_callstack(self, caller)}."
  end

  def track_initialization
    Rails.logger.info "A managed_work owned by a '#{self.owner_type}' was created. " \
                      "The call stack that created it was:\n#{Logging.format_callstack(self, caller)}."
  end
  # END temporary code

  ACTIVE_TEXT = { MANAGED_WORK_INACTIVE => N_('Inactive - the client has disabled review for this job'),
                  MANAGED_WORK_ACTIVE => N_('Review is needed for this job') }.freeze

  REVIEW_STATUS_TEXT = { REVIEW_NOT_NEEDED => N_('Not ready for review'),
                         REVIEW_PENDING_ALREADY_FUNDED => N_('Waiting for review'),
                         REVIEW_COMPLETED => N_('Review complete') }.freeze

  REVIEW_ACIVE_TEXT = { MANAGED_WORK_INACTIVE => N_('Review disabled'),
                        MANAGED_WORK_ACTIVE => N_('Review enabled') }.freeze

  REVIEW_TYPE_TEXT =  { REVIEW_AND_CREATE_ISSUE => N_('The reviewer suggests the translator how to edit the text'),
                        REVIEW_AND_EDIT => N_('The reviewer is allowed to edit the text') }.freeze

  def active?
    active == MANAGED_WORK_ACTIVE
  end

  def enabled?
    [MANAGED_WORK_ACTIVE, MANAGED_WORK_PENDING_PAYMENT].include? active
  end

  def disabled?
    !enabled?
  end

  def reviewing?
    translation_status == MANAGED_WORK_REVIEWING
  end

  def can_cancel?
    active? && reviewing?
  end

  def pending_payment?
    active == MANAGED_WORK_PENDING_PAYMENT
  end

  def wait_for_payment
    self.active = MANAGED_WORK_PENDING_PAYMENT
    save!
  end

  def disable
    transaction do
      return if disabled?
      refund unless pending_payment?

      if owner.is_a? WebMessage
        destroy
      else
        update_attribute :active, MANAGED_WORK_INACTIVE
      end
    end
  end

  def activate
    self.active = MANAGED_WORK_ACTIVE
    save!
  end

  def has_escrow?
    case owner
    when WebsiteTranslationOffer, WebMessage
      false
    else
      true
    end
  end

  def escrow_account
    case owner
    when RevisionLanguage
      owner.selected_bid.account
    else
      raise "Unknown owner: #{owner}"
    end
  end

  def has_translator?
    !!translator_id
  end

  def waiting_for_reviewer?
    translation_status == MANAGED_WORK_WAITING_FOR_REVIEWER
  end

  def client_account
    case owner
    when RevisionLanguage
      owner.revision.client.find_or_create_account(DEFAULT_CURRENCY_ID)
    else
      raise "Unknown owner: #{owner}"
    end
  end

  def complete?
    translation_status == MANAGED_WORK_COMPLETE
  end

  def complete!
    update_attribute(:translation_status, MANAGED_WORK_COMPLETE)
  end

  def waiting_for_payment?
    translation_status == MANAGED_WORK_WAITING_FOR_PAYMENT
  end

  def reviewer_payment
    case owner
    when RevisionLanguage
      owner.selected_bid.reviewer_payment
    else
      raise "Unknown owner: #{owner}"
    end
  end

  def cancel_event
    case owner
    when RevisionLanguage
      TRANSFER_REFUND_FROM_BID_ESCROW
    else
      raise "Unknown owner: #{owner}"
    end
  end

  def refund
    if has_escrow?
      MoneyTransactionProcessor.transfer_money(escrow_account,
                                               client_account,
                                               reviewer_payment,
                                               DEFAULT_CURRENCY_ID,
                                               cancel_event)
    end
  end

  # Working wiht bidding projects only
  def cancel
    disable
    self.translation_status = MANAGED_WORK_CREATED
    save!
  end

  def self.default(args)
    ManagedWork.new(active: MANAGED_WORK_INACTIVE,
                    translation_status: MANAGED_WORK_CREATED,
                    from_language_id: args[:from_language_id],
                    to_language_id: args[:to_language_id],
                    notified: 0)
  end

  def client
    if owner.class == ResourceLanguage
      owner.text_resource.client
    elsif owner.class == WebMessage
      return owner.owner if owner.owner.class == Client
    elsif owner.class == RevisionLanguage
      owner.revision.project.client
    elsif owner.class == WebsiteTranslationOffer
      owner.website.client
    end
  end

  def owner_project
    if owner.is_a? WebMessage
      owner
    elsif owner.is_a? ResourceLanguage
      owner.text_resource
    elsif owner.is_a? WebsiteTranslationOffer
      owner.website
    elsif owner.is_a? RevisionLanguage
      owner.revision
    else
      raise "Unknown owner type: #{owner.class}"
    end
  end

  def blocked_translators

    unless @blocked_translators
      if owner.class == ResourceLanguage
        @blocked_translators =
          owner.resource_chats.
          where('resource_chats.status in (?)', [RESOURCE_CHAT_ACCEPTED]).
          map(&:translator)
      elsif owner.class == WebMessage
        @blocked_translators = [owner.translator] if owner.owner.class == Client
      elsif owner.class == RevisionLanguage
        @blocked_translators =
          owner.bids.
          where('bids.status not in (?)', [BID_GIVEN, BID_TERMINATED]).
          collect { |bid| bid.chat.translator }
      elsif owner.class == WebsiteTranslationOffer
        @blocked_translators =
          owner.website_translation_contracts.
          where('website_translation_contracts.status in (?)', [TRANSLATION_CONTRACT_ACCEPTED]).
          map(&:translator)
      end
    end

    @blocked_translators
  end

  def translator_can_apply_to_review(translator)

    # make sure that the translator is qualified to review in this language pair
    unless translator.from_lang_ids.include?(from_language_id) &&
           translator.to_lang_ids.include?(to_language_id) &&
           translator.level == EXPERT_TRANSLATOR &&
           [USER_STATUS_REGISTERED, USER_STATUS_QUALIFIED].include?(translator.userstatus)
      logger.debug "--------- not qualified to review - translator.level=#{translator.level}"
      return false
    end

    # make sure that the client didn't decline this translator's application to translate
    if blocked_translators.include?(translator)
      logger.debug '--------- blocked from this project'
      return false
    end

    if owner.is_a?(RevisionLanguage) && owner.selected_bid
      owner.selected_bid.chat.translator != translator
    end
    true
  end

  def unassign_reviewer
    self.translator_id = nil
    save
  end

  def owner_translators
    if owner.class == ResourceLanguage
      owner.selected_chat ? [owner.selected_chat.translator] : []
    elsif owner.class == RevisionLanguage
      if owner.selected_bid && owner.selected_bid.chat
        [owner.selected_bid.chat.translator]
      else
        []
      end
    elsif owner.class == WebsiteTranslationOffer
      owner.accepted_website_translation_contracts
    elsif owner.class == WebMessage
      [owner.translator]
    else
      raise 'Unknow project type'
    end

  end

  # For website translation projects, call
  # `WebsiteTranslationOffer#assign_reviewer_to_managed_work` instead. It does
  # other required things, then it calls this method.
  def assign_reviewer(id)
    begin
      new_reviewer = Translator.find(id)
    rescue
      raise 'Invalid translator'
    end

    if owner_translators.include?(new_reviewer)
      raise "A translator can't be the reviewer and translator at same time"
    end

    self.translator_id = id
    if translation_status == MANAGED_WORK_WAITING_FOR_REVIEWER
      self.translation_status = MANAGED_WORK_REVIEWING
    end
    save
  end

  def get_webta_review_status
    return WEBTA_REVIEW_DISABLE unless self.active?
    return WEBTA_REVIEW_AND_EDIT if self.review_type == REVIEW_AND_EDIT
    WEBTA_REVIEW_AND_CREATE_ISSUE
  end

  class << self
    def resign_all_website_reviews(user, website, remarks = '')
      review_jobs = where(owner_type: 'WebsiteTranslationOffer', owner_id: website.website_translation_offers.map(&:id), translation_status: MANAGED_WORK_REVIEWING, translator: user)
      if review_jobs.present?
        review_jobs.update_all(owner_type: 'WebsiteTranslationOffer', translation_status: MANAGED_WORK_WAITING_FOR_REVIEWER, translator_id: nil)
        website.cms_requests.each do |cms_request|
          cms_request.revision.revision_languages.each do |rl|
            rl.managed_work.update_attributes(translation_status: MANAGED_WORK_WAITING_FOR_REVIEWER, translator_id: nil) if rl.managed_work
          end
        end
      end
      TranslatorsRefusedProject.refuse_project(website, user, 'reviewer', remarks) if user.is_a?(Translator)
    end
  end

end
