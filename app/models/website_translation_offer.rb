# Besides corresponding to translation job offers created by clients for
# translators to apply, each instance of this model also corresponds to one
# language pair in one website (which may have multiple cms_requests).
#
# Statuses:
#   TRANSLATION_OFFER_OPEN = 0 - Allow translators to apply for this job.
#   The language pair appears on the "Open Work" page of all translators that
#   are qualified to translate in this language pair.
#
#   TRANSLATION_OFFER_CLOSED = 1 - Translators are not allowed to apply. Does
#   not appear in the "Open Work" page. The client has to invite translators.
#
#   TRANSLATION_OFFER_SUSPENDED = 2 - Suspended, translators cannot translate.
class WebsiteTranslationOffer < ApplicationRecord
  include KeywordProjectLanguage
  keyword_language_associations

  belongs_to :website
  belongs_to :from_language, class_name: 'Language', foreign_key: 'from_language_id'
  belongs_to :to_language, class_name: 'Language', foreign_key: 'to_language_id'
  belongs_to :active_trail_action, optional: true

  has_one :managed_work, as: :owner, dependent: :destroy

  has_many :website_translation_contracts, dependent: :destroy
  has_many :applied_website_translation_contracts,
           -> { where.not(status: TRANSLATION_CONTRACT_NOT_REQUESTED) },
           class_name: 'WebsiteTranslationContract',
           foreign_key: 'website_translation_offer_id'
  has_many :accepted_website_translation_contracts,
           -> { where(status: TRANSLATION_CONTRACT_ACCEPTED) },
           class_name: 'WebsiteTranslationContract',
           foreign_key: 'website_translation_offer_id'
  has_many :sent_notifications, as: :owner, dependent: :destroy
  has_many :cms_counts, dependent: :destroy

  validates_each :from_language_id, :to_language_id do |model, attr, value|
    if value.blank? || (value <= 0)
      model.errors.add(attr, _('must be specified'))
    end
  end
  validates :from_language_id, :to_language_id, presence: true
  # Custom validations
  validate :valid_from_and_to_language
  validate :automatic_translator_assignment_validation

  validates :website_id, uniqueness: {
    scope: [:from_language_id, :to_language_id],
    message: 'Cannot have more than one WebsiteTranslationOffer per language pair.'
  }

  after_create :set_default_translator_assignment_mode

  def self.count_of_no_accepted_contracts
    needs_auto_assignment.count
  end

  # Language pairs that require automatic translator assignment, meaning a
  # client sent contents for translation, chosen automatic translator
  # assignment, paid, and not translators were assigned so far.
  def self.needs_auto_assignment
    query = <<-SQL
      SELECT DISTINCT
        wto.id,
        source_language.name AS source_language_name,
        target_language.name AS target_language_name,
        websites.id as website_id,
        websites.name as website_name
      FROM website_translation_offers AS wto
        INNER JOIN websites
          ON wto.website_id = websites.id
        INNER JOIN cms_requests
          ON wto.from_language_id = cms_requests.language_id
             AND websites.id = cms_requests.website_id
        INNER JOIN cms_target_languages AS ctl
          ON cms_requests.id = ctl.cms_request_id
             AND wto.from_language_id = ctl.language_id
        -- Laguage has at least one paid CmsRequest
        INNER JOIN pending_money_transactions AS pmt
          ON cms_requests.id = pmt.owner_id
             AND pmt.owner_type = 'CmsRequest'
        INNER JOIN languages AS source_language
          ON wto.from_language_id = source_language.id
        INNER JOIN languages AS target_language
          ON wto.to_language_id = target_language.id
      WHERE wto.automatic_translator_assignment = 1
            -- There are no assigned translators (no WTCs with status 2)
            AND NOT EXISTS(SELECT 1
                           FROM website_translation_contracts AS wtc
                           WHERE wtc.website_translation_offer_id = wto.id
                                 AND wtc.status = #{TRANSLATION_CONTRACT_ACCEPTED}
                          )
    SQL

    WebsiteTranslationOffer.find_by_sql(query).uniq
  end

  # Returns the WebsiteTrantlationOffers that have review enabled, as per
  # the new flow rules
  def self.reviewable_language_pairs
    # In the past, website_translation_offer.managed_work.active was used to
    # determine two things: a) If review should be enabled or disabled by
    # default for a language pair; b) If the managed_work for this language
    # pair should appear on the translators "Open Work" page.
    #
    # Currently, we still use it for the former (a), but not for the latter (b).
    # Currently, to know if a website_translation_offer.managed_work should
    # should appear for translators, we must check if it has at least one
    # CmsRequest that is: paid, not complete and has review enabled.
    #
    # In the following query, pending_money_transactions are joined to
    # determine if the cms_request is paid. The pending_money_transactions
    # table uses the paranoid gem and we're intentionally including deleted
    # rows in the query. If a cms_request has an associated
    # pending_money_transaction (deleted or not), it means it's paid for.
    query = <<-SQL
      SELECT wto.*
      FROM cms_requests
        INNER JOIN pending_money_transactions pmt
          ON pmt.owner_id = cms_requests.id
             AND pmt.owner_type = 'CmsRequest'
        INNER JOIN cms_target_languages AS ctl
          ON ctl.cms_request_id = cms_requests.id
        INNER JOIN website_translation_offers AS wto
          ON wto.website_id = cms_requests.website_id
             AND wto.from_language_id = cms_requests.language_id
             AND wto.to_language_id = ctl.language_id
             AND wto.automatic_translator_assignment = 0
      WHERE cms_requests.status <= 5
        AND cms_requests.review_enabled
      GROUP BY wto.id
    SQL

    WebsiteTranslationOffer.find_by_sql(query)
  end

  def self.automatic_translator_assignment_usage_report(options = { per_language: false })
    scope = 'COUNT(DISTINCT CASE WHEN wto.automatic_translator_assignment IS TRUE THEN wto.website_id END) as accepted_count, ' \
            'COUNT(DISTINCT(wto.website_id)) as total_count'
    scope += ', source_language.name AS source_language_name, target_language.name AS target_language_name' if options[:per_language] == true
    sql = <<-SQL
      SELECT
        #{scope}
      FROM website_translation_offers as wto
        INNER JOIN websites ON wto.website_id = websites.id
        INNER JOIN cms_requests
          ON wto.from_language_id = cms_requests.language_id
            AND websites.id = cms_requests.website_id
        INNER JOIN cms_target_languages AS ctl
          ON cms_requests.id = ctl.cms_request_id
            AND wto.from_language_id
        INNER JOIN pending_money_transactions AS pmt
          ON cms_requests.id = pmt.owner_id
            AND pmt.owner_type = 'CmsRequest'
        INNER JOIN languages AS source_language
          ON wto.from_language_id = source_language.id
        INNER JOIN languages AS target_language
          ON wto.to_language_id = target_language.id
        INNER JOIN language_pair_fixed_prices
          ON language_pair_fixed_prices.from_language_id = wto.from_language_id
            AND language_pair_fixed_prices.to_language_id = wto.to_language_id
            AND language_pair_fixed_prices.published IS TRUE
      WHERE websites.api_version = '2.0'
    SQL
    if options[:per_language] == true
      sql += ' GROUP BY source_language_name, target_language_name ORDER BY accepted_count DESC'
    end
    WebsiteTranslationOffer.find_by_sql(sql)
  end

  def language_id
    to_language_id
  end

  def language
    to_language
  end

  def translator
    website.representative_translator_for(language)
  end

  def project
    website
  end

  def invite_translator(translator)
    invitation_text =
      "I would like you to translate my website '#{website.name}' from " \
      "#{self.from_language.name} to #{self.to_language.name}. There are " \
      "#{self.word_count} words to be translated and the deadline is " \
      "#{self.estimated_completion_date&.strftime(DATE_FORMAT_STRING) || 'as soon as possible'}."

    website_translation_contract = WebsiteTranslationContract.create!(
      invited: 1,
      status: TRANSLATION_CONTRACT_NOT_REQUESTED,
      currency_id: DEFAULT_CURRENCY_ID,
      website_translation_offer: self,
      translator: translator
    )

    message = Message.new(body: invitation_text, chgtime: Time.now)
    message.user = website.client
    message.owner = website_translation_contract
    if message.valid?
      message.save!
      message_delivery = MessageDelivery.new
      message_delivery.user = translator
      message_delivery.message = message
      message_delivery.save!
    end

    if translator.can_receive_emails?
      ReminderMailer.invite_to_cms(translator,
                                   website_translation_contract,
                                   invitation_text,
                                   self.sample_text).deliver_now
    end

    translator.create_reminder(EVENT_NEW_WEBSITE_TRANSLATION_MESSAGE,
                               website_translation_contract)

    # also list it as a sent notification
    SentNotification.create!(
      user: translator,
      owner: self
    )

    website_translation_contract
  end

  def invite_all_translators!
    all_translators = Translator.find_by_languages(
      nil,
      self.from_language_id,
      self.to_language_id
    )

    website_translation_contracts = []
    all_translators.each do |translator|
      website_translation_contracts << invite_translator(translator)
    end

    count = website_translation_contracts.compact.size
    self.update(invited_all_translators: true) if count > 0

    count
  end

  def allow_translators_to_apply!
    self.status = TRANSLATION_OFFER_OPEN
    save!

    unless managed_work
      managed_work = ManagedWork.new(active: MANAGED_WORK_INACTIVE, notified: 0, from_language_id: from_language.id, to_language_id: to_language.id)
      managed_work.owner = self
      managed_work.client = website.client
      managed_work.save!
    end
  end

  def auto_configure(deadline, words)
    deadline = deadline.to_date rescue 'undefined'
    words = words.to_i == '0' ? 'undefined' : words.to_i
    update_attribute :invitation, "There are #{words} words to be translated up to #{deadline.strftime('%Y %b, %d')}"
  end

  STATUS_TEXT = { TRANSLATION_OFFER_OPEN => N_('Open for translators to bid'),
                  TRANSLATION_OFFER_CLOSED => N_('Closed for bidding'),
                  TRANSLATION_OFFER_SUSPENDED => N_('Suspended, translators cannot translate') }.freeze

  def project_name
    website.name
  end

  def language_pair
    _('%s to %s') % [from_language.nname, to_language.nname]
  end

  def status_summary(user = nil)
    if website_translation_contracts.empty?
      _('Translators did not apply for this work yet')
    else
      on_vacation_cnt = 0
      accepted_website_translation_contracts.each do |accepted_website_translation_contract|
        if accepted_website_translation_contract.translator.on_vacation?
          on_vacation_cnt += 1
        end
      end

      on_vacation_txt = on_vacation_cnt > 0 ? (' <span class="warning">(' + _('%d on planned leave') % on_vacation_cnt + ')</span>') : ''

      res = _('%d translator(s) applied for this work. %d offer(s) accepted.') % [applied_website_translation_contracts.length, accepted_website_translation_contracts.length] + on_vacation_txt

      new_messages = 0
      applied_website_translation_contracts.each { |contract| new_messages += contract.new_messages(user).length }
      if new_messages > 0
        res += '<br /><b>' + _('%d new messages') % new_messages + '</b>'
      end
      res.html_safe
    end
  end

  def available_translators
    return 1 if have_translators == 1
    al = AvailableLanguage.where('(from_language_id=?) AND (to_language_id=?) AND (qualified=2)', from_language_id, to_language_id).first
    al ? '1' : '0'
  end

  def have_translators
    !accepted_website_translation_contracts.empty? ? 1 : 0
  end

  # Translators that were invited by the client. Includes those who replied,
  # thoso who did not reply, those who were accepted and those who didn't.
  def translators_invited
    Translator.where(id: website_translation_contracts.pluck(:translator_id))
  end

  # Translators that were invited by the client. Includes those who replied,
  # those who did not reply, those who were accepted and those who didn't.
  def translator_invitations_count
    # Each translator which is invited (or applies without being invited)
    # creates a new website_translation_contract.
    website_translation_contracts.size
  end

  # Translators that were invited by the client. Includes those who replied,
  # those who did not reply, those who were accepted and those who didn't.
  def any_translators_invited?
    translator_invitations_count > 0
  end

  # Translators that were invited by the client but did not yet reply.
  def pending_translator_invitations
    website_translation_contracts.where(status: TRANSLATION_CONTRACT_NOT_REQUESTED)
  end

  # Translators that were invited by the client but did not yet reply.
  def pending_translator_invitations_count
    pending_translator_invitations.size
  end

  # Translators that accepted the client's invitation or applied without being
  # invited (if the project is configured to allow that).
  def translators_applied
    Translator.where(id: applied_website_translation_contracts.pluck(:translator_id))
  end

  # The count includes both translators that applied after being invited and
  # those who applied without being invited (if the project settings allow that)
  def translators_applied_count
    applied_website_translation_contracts.size
  end

  def any_translators_applied?
    translators_applied_count > 0
  end

  def translators_accepted_count
    accepted_website_translation_contracts.size
  end

  def any_translators_accepted?
    translators_accepted_count > 0
  end

  # Translators that applied but got no reply from the client (client did not
  # accept nor deny the translator application)
  def pending_translator_applications
    website_translation_contracts.where(status: TRANSLATION_CONTRACT_REQUESTED)
  end

  def pending_translator_applications_count
    pending_translator_applications.size
  end

  # Translators whose applications/bids were accepted by the client.
  def translators_accepted
    Translator.where(id: accepted_website_translation_contracts.pluck(:translator_id))
  end

  # Check if all translators accepted for this language pair are private
  # translators. Private translators always work for free (all their translation
  # jobs cost $0).
  def all_translators_are_private?
    accepted_wtcs = accepted_website_translation_contracts
    return false if accepted_wtcs.empty?

    accepted_wtcs.includes(:translator).all? do |wtc|
      wtc&.translator&.private_translator?
    end
  end

  # CmsRequests for this language pair in this website
  def cms_requests
    website.cms_requests.includes(:cms_target_languages).where(
      language: from_language,
      cms_target_languages: { language: to_language }
    )
  end

  # "Unstarted" means a translator did not yet take a cms_request. In other
  # words a trabslator did not yet click the "Start Translation" button, which
  # triggers CmsRequestsController#assign_to_me)
  def unstarted_cms_requests
    # When a cms_request's associated CmsTargetLanguage status is
    # CMS_TARGET_LANGUAGE_CREATED, if the cms_request was paid for, the amount
    # required for that cms_request was *not yet* moved from the client's "hold
    # balance" to an escrow account by CmsRequestsController#assign_to_me.
    website.
      cms_requests.
      includes(:cms_target_languages).
      where(
        language: from_language,
        status: [CMS_REQUEST_CREATING..CMS_REQUEST_RELEASED_TO_TRANSLATORS],
        cms_target_languages: { status: CMS_TARGET_LANGUAGE_CREATED,
                                language_id: to_language.id }
      )
  end

  # "Pending" means that a cms_request was created but not paid for yet.
  #
  # For language pairs with automatic translator assignment enabled, the client
  # can pay immediately after contents are sent from WPML (and cms_requests are
  # created automatically).
  #
  # For language pairs with manual translator assignment, if it's the first time
  # a client sends contents for that language pair in that website (no
  # translators were assigned to the language pair yet), the client must first
  # accept a translator, then he can pay. If translators were already assigned
  # because the user has sent content for that language pair before, then he
  # can pay immediately after the content is sent.
  def all_pending_cms_requests
    # When a cms_request has an associated PendingMoneyTransaction record, it
    # means it's already paid for and the amount is on the client's "hold
    # balance" (it was not yet moved to an escrow account).
    pending_cms_request_ids = unstarted_cms_requests.pluck(:id) - cms_requests_with_reserved_balance_ids
    CmsRequest.where(id: pending_cms_request_ids)
  end

  def processed_pending_cms_requests
    # The following 2 criteria indicate that the CmsRequest is done
    # processing by both TAS and WebTA (otgs-segmenter gem). Displaying
    # CmsRequests that are not done processing to clients and allowing them
    # to be paid creates many issues such as:
    # - When the client pays for a CmsRequest, it has no word_count yet, so
    # the amount paid is zero. Or is has a word count which is updated after
    # processing is done (see ParsedXliff#update_ctl_word_count). Then the
    # amount paid by the client (and moved to hold_sum by PendingMoneyTransaction)
    # is not enough to cover the price of the CmsRequest and many issues occur.
    all_pending_cms_requests.where(xliff_processed: true, pending_tas: false)
  end

  def any_pending_cms_requests?
    all_pending_cms_requests.size > 0
  end

  def any_processed_pending_cms_requests?
    processed_pending_cms_requests.size > 0
  end

  def paid_cms_requests
    # TODO: refactor to a single SQL query while still returning an ActiveRecord::Relation object.
    # TODO: The association with PendingMoneyTransaction is polymorphic, so it's a complex query.

    # When a cms_request's associated CmsTargetLanguage status is
    # CMS_TARGET_LANGUAGE_CREATED, it means the amount required for that
    # cms_request was *not yet* moved from the client's "hold balance" to an
    # escrow account (by CmsRequestsController#assign_to_me).
    cms_requests_with_paid_status_ids =
      cms_requests.includes(:cms_target_languages).where('cms_target_languages.status != 0').pluck(:id)

    # When a cms_request has an associated PendingMoneyTransaction record, it
    # means it's already paid for and the amount is on the client's "hold
    # balance" (it was not yet moved to an escrow account).
    paid_cms_requests_ids = cms_requests_with_paid_status_ids + cms_requests_with_reserved_balance_ids

    CmsRequest.where(id: paid_cms_requests_ids)
  end

  def any_paid_cms_requests?
    paid_cms_requests.size > 0
  end

  def first_accepted_contract_id
    !accepted_website_translation_contracts.empty? ? accepted_website_translation_contracts[0].id : 0
  end

  # Is review enabled for the *pending* cms_requests of this language pair.
  # Pending cms_requests are not yet paid for.
  def review_enabled_for_pending_jobs?
    all_pending_cms_requests.pluck(:review_enabled).any?
  end

  # Is review enabled for the *unstarted* cms_requests of this language pair.
  # Unstarted cms_requests can be paid for or not, but translation has not
  # yet started.
  def review_enabled_for_unstarted_jobs?
    unstarted_cms_requests.pluck(:review_enabled).any?
  end

  # Enable review for all *pending* cms_requests of this language pair.
  # cms_requests that are already paid for (not pending) are not affected.
  def enable_review_for_pending_jobs
    all_pending_cms_requests.update_all(review_enabled: true)
  end

  # Disable review for all *pending* cms_requests of this language pair
  # cms_requests that are already paid for (not pending) are not affected.
  def disable_review_for_pending_jobs
    all_pending_cms_requests.update_all(review_enabled: false)
  end

  # Is review enabled **by default** for this language pair? Does not refer to
  # the enabled/disabled status of any individual translation jobs.
  def review_enabled_by_default?
    managed_work&.active == 1 || false
  end

  # Make "enabled" the default/initial review state in the "Pending Translation
  # Jobs" page when new content is received for translation. Does **not**
  # affect any existing translation jobs.
  def enable_review_by_default
    managed_work&.update(active: 1)
  end

  # Make "disabled" the default/initial review state in the "Pending Translation
  # Jobs" page when new content is received for translation. Does **not**
  # affect any existing translation jobs.
  def disable_review_by_default
    managed_work&.update(active: 0)
  end

  def create_contract_for_translators(translator)
    raise 'Unable to assign translator: Translator can not be a reviewer at the same time' if self.managed_work.try(:translator) == translator
    translators_language_pair_rate = translator.language_pair_autoassignments.where(from_language: from_language, to_language: to_language).first
    raise 'Language pair rate is not defined' unless translators_language_pair_rate.present?
    contract = website_translation_contracts.create(translator: translator, invited: 1,
                                                    status: TRANSLATION_CONTRACT_ACCEPTED,
                                                    currency_id: DEFAULT_CURRENCY_ID,
                                                    amount: translators_language_pair_rate.min_price_per_word)
    ReminderMailer.notify_translator_for_auto_assigned_project(contract).deliver_now
    contract
  end

  def assign_reviewer_to_managed_work(translator, review_type = nil)
    raise 'Unable to assign reviewer at this time, please contact support' if self.managed_work.nil?
    raise 'The selected translator does not meet the criteria to review this job' \
      unless managed_work.translator_can_apply_to_review(translator)
    # Using 'REVIEW_AND_CREATE_ISSUE' as a default value for the review_type
    # argument does not work if the method receives nil as the review_type
    # argument (nil replaces the default value).
    review_type ||= 'REVIEW_AND_CREATE_ISSUE'
    # A reviewer can be assigned (or replaced) regardless of whether the
    # translator (the first translator, not the reviewer) has started to
    # translate or not. When the translator clicks the "Start Translation"
    # button, it triggers CmsRequestsController#assign_to_me, which creates a
    # revision_language, a revision_language.managed_work and it
    # copies the website_translation_offer.managed_work.translator to
    # revision_language.managed_work.translator.
    #
    # If #assign_reviewer_to_managed_work was always called before
    # CmsRequestsController#assign_to_me, we would not need the following
    # lines of code, because #assign_to_me would set the
    # revision_language.managed_work_translator. However, there are cases when
    # the reviwer is assigned after #assign_to_me is called, so we have to
    # set the revision_language.managed_work_translator for all CmsRequests here.
    self.cms_requests.each do |cms_request|
      cms_request.revision&.revision_languages&.each do |rl|
        rl.managed_work.assign_reviewer(translator.id) if rl.managed_work
      end
    end
    managed_work.update_attributes(review_type: review_type.constantize, active: MANAGED_WORK_ACTIVE)
    managed_work.assign_reviewer(translator.id)
    ReminderMailer.notify_reviewer_for_auto_assigned_project(self).deliver_now
  end

  def assign_and_create_contract(translator_params_list)
    assigned_params = []
    contracts = []
    translator_params_list.each_with_index do |params, _key|
      next unless params['id'].present? && params['type'].present?
      begin
        translator = Translator.find(params['id'])
        contract = params['type'] == 'translator' ? create_contract_for_translators(translator) : assign_reviewer_to_managed_work(translator, params[:review_type])
        params['is_assigned'] = contract.present?
        contracts << contract unless contract.nil?
      rescue => e
        params['is_assigned'] = false
        params['reason'] = e.message
      end
      assigned_params << params
    end
    # TODO: As discussed, this will be disabled for now until new flow for it is gave.
    # ReminderMailer.notify_client_for_auto_assigned_project(self, contracts).deliver_now if contracts.present?
    assigned_params
  end

  def get_translator_contracts(translator)
    self.website_translation_contracts.where(translator: translator, status: [TRANSLATION_CONTRACT_NOT_REQUESTED, TRANSLATION_CONTRACT_REQUESTED, TRANSLATION_CONTRACT_ACCEPTED])
  end

  def has_existing_translation_contract(translator)
    get_translator_contracts(translator).present?
  end

  def self.offers_for_supporter
    all_offers = WebsiteTranslationOffer.
                 joins(:website).
                 where(
                   '(websites.project_kind != ?) AND (websites.interview_translators != ?) AND (website_translation_offers.status = ?)',
                   TEST_CMS_WEBSITE,
                   CLIENT_INTERVIEWS_TRANSLATORS,
                   TRANSLATION_OFFER_OPEN
                 )
    filter_offers(all_offers)
  end

  def self.offers_without_translators
    all_offers = WebsiteTranslationOffer.
                 joins(:website).
                 where(
                   '(websites.project_kind != ?) AND (website_translation_offers.status = ?) AND NOT EXISTS(SELECT * FROM available_languages WHERE ((available_languages.from_language_id=website_translation_offers.from_language_id) AND (available_languages.to_language_id=website_translation_offers.to_language_id) AND (available_languages.qualified = 2)))',
                   TEST_CMS_WEBSITE,
                   TRANSLATION_OFFER_OPEN
                 )

    filter_offers(all_offers)
  end

  # Translation jobs that are paid for and available for translators to start
  # translating. If a CmsRequest has an associated PendingMoneyTransaction, it
  # means it's paid (there is money reserved for in in the clients hold_sum).
  def open_cms_target_languages
    query = <<-SQL
      SELECT cms_target_languages.*
        FROM cms_target_languages
          INNER JOIN cms_requests
            ON cms_target_languages.cms_request_id = cms_requests.id
          INNER JOIN pending_money_transactions
            ON pending_money_transactions.owner_id = cms_requests.id
               AND pending_money_transactions.owner_type = 'CmsRequest'
         WHERE cms_requests.website_id = #{website_id}
              AND cms_requests.language_id = #{from_language_id}
              AND cms_target_languages.language_id = #{to_language_id}
              AND cms_requests.status = #{CMS_REQUEST_RELEASED_TO_TRANSLATORS}
              AND cms_target_languages.translator_id IS NULL
    SQL

    CmsTargetLanguage.find_by_sql(query)
  end

  def open_work_stats
    cms_target_languages = open_cms_target_languages
    word_count = 0
    cms_target_languages.each { |ctl| word_count += ctl.word_count }
    [cms_target_languages.length, word_count]
  end

  def translator_can_apply(translator)
    blocked_translators = []
    if managed_work && (managed_work.active == MANAGED_WORK_ACTIVE)
      blocked_translators << managed_work.translator
    end
    !blocked_translators.include?(translator)
  end

  def set_reviewer(reviewer)
    unless managed_work
      self.managed_work = ManagedWork.create!(
        active: MANAGED_WORK_ACTIVE,
        from_language: self.from_language,
        to_language: self.to_language,
        client: self.website.client
      )
    end
    managed_work.update_attribute :translator_id, reviewer.id
  end

  def self.filter_offers(offers)
    res = []
    offers.each do |offer|
      if offer.website && offer.website.client && offer.website.client.userstatus == USER_STATUS_REGISTERED
        res << offer
      end
    end
    res
  end

  # Total word count of all CMS requests regarding this language pair for
  # this website.
  def word_count
    CmsTargetLanguage.where(cms_request: processed_pending_cms_requests).sum(:word_count)
  end

  # Price per word for this language pair, NOT including review.
  def price_per_word_without_review
    return price_for_automatic_translator_assignment if automatic_translator_assignment
    price_for_manual_translator_assignment
  end

  # Price per word for this language pair.
  # The only valid use case for this method is to calculate the price at the
  # time the client is charged ("Pending Translation Jobs" and "Payment" pages).
  # In other words, it is only OK to calculate the word count per language pair
  # (as opposed to per CmsRequest) because at the time of payment, review can
  # only be enabled or disabled for all **pending** CmsRequests in the language
  # pair. So this method should only be used at that time (because its a lot
  # faster than CmsRequest#calculate_required_balance). In all further points in
  # the workflow, the price per word must be calculated per CmsRequest and take
  # into account the translator that is working on it (we may have translators
  # with different bid amounts in the same language pair) and if review is
  # enabled or disabled for that specific CmsRequest.
  def total_price_per_word
    # Private translators have zero cost
    return 0 if all_translators_are_private?

    review_price_per_word = review_enabled_for_pending_jobs? ? (price_per_word_without_review * REVIEW_PRICE_PERCENTAGE) : 0
    price_per_word_without_review + review_price_per_word
  end

  def total_price
    # TODO: optimize for better performance
    processed_pending_cms_requests.reduce(0) do |sum, cms_request|
      cms_request_amount =
        cms_request.calculate_required_balance([cms_request.cms_target_language])[0]
      sum + cms_request_amount
    end
  end

  # Greatest (farthest) deadline amongst this language pair's translation jobs
  # (including reviews).
  def estimated_completion_date
    processed_pending_cms_requests.maximum(:deadline)
  end

  def language_pair_fixed_price
    LanguagePairFixedPrice.where(
      from_language: from_language,
      to_language: to_language
    ).first
  end

  def automatic_translator_assignment_available?
    # Automatic translator assignment is not possible when the language pair
    # is not "known" (doesn't have enough translators or preexisting
    # translation jobs to calculate a reliable fixed price).
    # eduard 14-12-2017 added check for website because users of old ICL service get all new language pairs with automatic
    language_pair_fixed_price.try(:known_language_pair?) && self.website.api_version == '2.0'
  end

  # After a language pair received its first payment, the client can no longer
  # change the translator assignment mode (between automatic and manual)
  def can_change_translator_assignment_mode?
    !any_paid_cms_requests?
  end

  def enable_automatic_translator_assignment!
    # Validation (automatic_translator_assignment_available? and
    # can_change_translator_assignment_mode?) is done via ActiveRecord callback
    self.update(automatic_translator_assignment: true, status: TRANSLATION_OFFER_CLOSED)
  end

  def disable_automatic_translator_assignment!
    # Validation (automatic_translator_assignment_available? and
    # can_change_translator_assignment_mode?) is done via ActiveRecord callback
    self.update(automatic_translator_assignment: false, status: TRANSLATION_OFFER_OPEN)
  end

  # Are there any pending CMS Requests in this language pair and is the language
  # pair price per word already determined? If yes, the client can pay.
  def client_can_pay?
    # If there are no pending cms requests, there is nothing to pay for
    return false unless any_pending_cms_requests?

    # Fixed prices are used with automatic translator assignment, so they do not
    # depend on the client accepting bids to determine the price. Hence, they
    # are "payable" from the moment they acre created.
    return true if automatic_translator_assignment

    # If manual translator assignment is used AND all translators
    # accepted/assigned to this language pair are private translator is, the
    # cost will always be zero.
    return true if all_translators_are_private?

    # When manual translator assignment is used and private translators are NOT
    # used, there must be a price > 0. The price can only be calculated after
    # the client accepts at least one bid from a translator.
    price = price_for_manual_translator_assignment
    price.present? && price > 0
  end

  def invite_translators_path
    "/websites/73108/language_pair?project_id=#{website.id}&" \
    "source_language=#{from_language.name}&" \
    "target_language=#{to_language.name}&disp_mode=#{DISPLAY_ALL_TRANSLATORS}&compact=1"
  end

  def accept_translators_path
    "/websites/73108/language_pair?project_id=#{website.id}&" \
    "source_language=#{from_language.name}&" \
    "target_language=#{to_language.name}&disp_mode=#{DISPLAY_ACCEPTED_TRANSLATORS}"
  end

  private

  def cms_requests_with_reserved_balance_ids
    # When a cms_request has an associated PendingMoneyTransaction record, it
    # means it's already paid for and the amount is on the client's "hold
    # balance" (it was not yet moved to an escrow account).
    PendingMoneyTransaction.where(
      owner_type: 'CmsRequest',
      # Only include cms_requests of this language pair
      owner_id: cms_requests.pluck(:id)
    ).pluck(:owner_id)
  end

  def price_for_automatic_translator_assignment
    language_pair_fixed_price.actual_price
  end

  def price_for_manual_translator_assignment
    # Translators will apply (bid) to this job and once the client accepts a
    # translator and he takes the job, we will know the price. Note that the
    # client can accept the applications of multiple translators and the
    # translator who takes the job first will keep it. However, the client
    # must pay before the a translator can take the job (start working). So,
    # when more than one translator's application is accepted, before the client
    # pays, we have no way of knowing which translator will get the job. If
    # the bids of the accepted translators have different values, we must
    # charge the client with value of the highest bid and, if a translator
    # with a lower bid value takes the job, we'll refund the difference to the
    # client.
    #
    # The app uses CmsRequest.calculate_required_balance to calculate the amount
    # the client has to pay for each CmsRequest. That method does NOT use
    # rounded price per word (e.g., 0.09 + 0.045 for the review = 0.135 would
    # round to 0.14), so we can't round the price per word to 2 decimal places
    # here or else the price per word displayed to the client will be
    # inconsistent with the total price (word count * price per word).
    accepted_website_translation_contracts.maximum(:amount)
  end

  def set_default_translator_assignment_mode
    # Automatic translator assignment should be enabled by default, except in
    # language pairs where it's not available.
    if automatic_translator_assignment_available?
      self.enable_automatic_translator_assignment!
    else
      self.disable_automatic_translator_assignment!
    end
  end

  def valid_from_and_to_language
    errors.add(:base, _('From and to languages must be different')) if from_language_id == to_language_id
  end

  def automatic_translator_assignment_validation
    # Check if automatic_translator_assignment can be enabled
    if automatic_translator_assignment && !automatic_translator_assignment_available?
      errors.add(
        :automatic_translator_assignment,
        "can't be enabled because #{language_pair} is a rare language pair. " \
        'You will receive quotes from our translators.'
      )
    end

    # After the language pair received its first payment, the translator
    # assignment mode can no longer be changed.
    if automatic_translator_assignment_changed? && self.persisted? && any_paid_cms_requests?
      errors.add(
        :automatic_translator_assignment,
        "setting can't be changed because #{language_pair} has already " \
        'received one or more payments.'
      )
    end
  end

  class NotCreated < JSONError
    def initialize(wto)
      @code = WEBSITE_TRANSLATION_OFFER_NOT_CREATED
      @message = wto.errors.full_messages.join("\n")
    end
  end

end
