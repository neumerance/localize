#   platform_kind: (it is using drupal for WP)
#     TEST_CMS_WEBSITE = 0
#     WEBSITE_WORDPRESS = 1
#     WEBSITE_DRUPAL = 2
#
class Website < ApplicationRecord

  belongs_to :client
  belongs_to :category
  has_one :cms_container, foreign_key: :owner_id, dependent: :destroy
  has_many :website_translation_offers, dependent: :destroy
  has_many :website_translation_contracts, through: :website_translation_offers
  has_many :translators, through: :website_translation_contracts
  has_many :cms_requests, dependent: :destroy
  has_many :cms_target_languages, through: :cms_requests, source: :cms_target_language
  has_many :web_messages, as: :owner, dependent: :destroy
  has_many :cms_terms, dependent: :destroy
  has_one :support_ticket, as: :object, dependent: :destroy
  has_many :cms_count_groups, dependent: :destroy
  has_many :reminders, dependent: :destroy
  has_one :translation_analytics_profile, as: :project, dependent: :destroy
  has_many :translation_analytics_language_pairs, through: :translation_analytics_profile
  has_many :keyword_projects, through: :website_translation_offers
  has_many :shortcodes, dependent: :destroy
  has_many :website_shortcodes, dependent: :destroy
  has_many :invoices, as: :source
  has_many :error_cms_requests,
           lambda {
             where('((cms_requests.pending_tas=1) OR (cms_requests.status IN (?))) AND (cms_requests.updated_at < ?)',
                   [
                     CMS_REQUEST_WAITING_FOR_PROJECT_CREATION,
                     CMS_REQUEST_PROJECT_CREATION_REQUESTED,
                     CMS_REQUEST_CREATING_PROJECT
                   ],
                   Time.now - TAS_PROCESSING_TIME)
           },
           class_name: 'CmsRequest'

  has_one :testimonial, as: :owner, dependent: :destroy

  validates :name, :cms_kind, presence: true
  validates :name, length: { maximum: 255 }
  validates :url, :wp_login_url, url_field: true
  validate :valid_platform_kind
  validates_numericality_of :tm_use_threshold, greater_than: 1, only_integer: true

  PICKUP_TEXT = {
    PICKUP_BY_RPC_POST  => N_('Translations will be posted back using XML-RPC to your site.'),
    PICKUP_BY_POLLING   => N_('Your site will poll translations from our server.')
  }.freeze

  PROJECT_KIND_TEXT = {
    TEST_CMS_WEBSITE => N_('Test project'),
    DEVELOPMENT_CMS_WEBSITE => N_('Development site'),
    PRODUCTION_CMS_WEBSITE => N_('Production site')
  }.freeze

  before_create :setup_attrs
  before_save :encrypt_wp_credentials

  # Websites that have unpaid CmsRequests (CmsRequests that do not have a
  # corresponding PendingMoneyTransaction) and whose owners (clients) have
  # enough balance in their ICL account's to pay for *all* pending CmsRequests.
  def self.with_unpaid_cms_requests_and_enough_balance
    # Retrieve websites which have user.money_account.balance > 0 AND
    # have pending CmsRequests (no associated PendingMoneyTransaction AND
    # cms_request.cms_target_language.status == 0)
    query = <<-SQL
      SELECT DISTINCT websites.id, websites.name, websites.client_id, users.nickname, users.email
      FROM websites
        JOIN users
          ON users.id = websites.client_id
        JOIN money_accounts
          ON money_accounts.owner_id = users.id
          AND money_accounts.balance > 0
        JOIN cms_requests
          ON cms_requests.website_id = websites.id
        JOIN cms_target_languages AS ctl
          ON ctl.cms_request_id = cms_requests.id
          AND ctl.status = 0
      WHERE NOT EXISTS (SELECT 1
                        FROM pending_money_transactions as pmt
                        WHERE pmt.owner_id = cms_requests.id
                        AND pmt.owner_type = 'CmsRequest'
                        AND pmt.deleted_at IS NULL)
    SQL

    websites = Website.find_by_sql(query)

    # Select only the websites whose owner's balance is enough to pay for all of
    # their pending cms_requests. Also return their total_amount as it would be
    # too expensive to calculate again at the view. Returns a hash with websites
    # as keys and their total_amounts as values.
    # TODO: Optimize Website#total_amount. This takes 40 seconds to run on my machine and triggers way too many queries.
    resulting_websites = {}
    websites.each do |website|
      # CmsRequests set to manual translator assignment where a translator is
      # not yet accepted are not included in the total_amount, as there is no
      # way of knowing the price per word (which is determined by an accepted
      # WebsiteTranslationContract, which does not yet exist).
      # Memoize, this is very expensive
      total_amount = website.total_amount
      if total_amount > 0 && total_amount <= website.client.money_account.balance
        resulting_websites[website] = total_amount
      end
    end

    # Sort by descending total_amount
    resulting_websites.sort_by { |_, total_amount| -total_amount }.to_h
  end

  include KeywordProjectMethods
  def project_languages
    website_translation_offers
  end

  def purchased_keyword_packages
    website_translation_offers.map(&:purchased_keyword_packages).flatten
  end

  def languages
    website_translation_offers.map(&:to_language)
  end

  def translators_for(language)
    website_translation_offers.find_by(to_language_id: language.id).accepted_website_translation_contracts.map(&:translator)
  end

  def representative_translator_for(language)
    translators_for(language).max_by { |t| cms_target_languages.where(translator_id: t.id).count }
  end

  def reviewer_for(language)
    mw = website_translation_offers.find_by(to_language_id: language.id).try(:managed_work)
    mw.translator if mw && mw.active?
  end

  def is_test?
    project_kind == TEST_CMS_WEBSITE
  end

  def all_pending_cms_requests
    # TODO: Refactor to improve performance. Use query similar to the one in WebsiteTranslationOffer#processed_pending_cms_requests
    pending_cms_request_ids = []
    website_translation_offers.each do |wto|
      pending_cms_request_ids += wto.all_pending_cms_requests
    end
    CmsRequest.where(id: pending_cms_request_ids)
  end

  def processed_pending_cms_requests
    # TODO: Refactor to improve performance. Use query similar to the one in WebsiteTranslationOffer#processed_pending_cms_requests
    pending_cms_request_ids = []
    website_translation_offers.each do |wto|
      pending_cms_request_ids += wto.processed_pending_cms_requests
    end
    CmsRequest.where(id: pending_cms_request_ids)
  end

  def pending_tas_cms_requests
    cms_requests.where('pending_tas = ? OR status = ?', true, CMS_REQUEST_WAITING_FOR_PROJECT_CREATION)
  end

  def failed_cms_requests
    cms_requests.where('status = ?', CMS_REQUEST_FAILED)
  end

  def update_pending_translation_job_statuses
    website_translation_offers.each do |offer|
      offer.review_enabled_for_pending_jobs? ? offer.enable_review_for_pending_jobs : offer.disable_review_for_pending_jobs
    end
  end

  def total_amount
    contracts = {}
    # TODO: icldev-1936 if the 2 cms_target_languages are not specified AR
    # fires a query to cms_target_languages when executing:
    # cms_request.cms_target_language.language_id
    preload_associations = :cms_target_language,
                           :cms_target_languages,
                           :translator

    processed_pending_cms_requests.includes(*preload_associations).inject(0) do |total, cms_request|
      # ALL_LANGUAGES is a hash of id => Language record
      target_language =
        Language::ALL_LANGUAGES[cms_request.cms_target_language.language_id]
      translator = cms_request.translator
      # The contracts are usually the same for all website, so lets memoize
      # contracts
      contracts[[target_language, translator]] ||=
        cms_request.locate_contract(target_language, translator)
      contract = contracts[[target_language, translator]]

      total + cms_request.calculate_required_balance([cms_request.cms_target_language],
                                                     translator,
                                                     contract: contract).first
    end
  end

  # total_amount - balance of the user's ICL account
  def missing_amount
    account_balance = client.find_or_create_account(DEFAULT_CURRENCY_ID).balance
    missing_funds = total_amount - account_balance
    if missing_funds <= 0
      0
    else
      ('%.2f' % missing_funds).to_f
    end
  end

  def find_contract_for_translator(translator, source_language, target_language)
    website_translation_contracts.joins(:website_translation_offer).
      where('(website_translation_offers.from_language_id = ?) AND
         (website_translation_offers.to_language_id = ?) AND
         (website_translation_contracts.translator_id=?) AND
         (website_translation_contracts.status=?)', source_language.id, target_language.id, translator.id, TRANSLATION_CONTRACT_ACCEPTED).first
  end

  def setup_attrs
    self.accesskey = Digest::MD5.hexdigest(Time.now.to_s).gsub(/[^0-9a-z ]/i, '') # remoge special characters from access key as Pawel sugested
    self.accesskey_ok = ACCESSKEY_VALIDATED
    self.platform_kind = WEBSITE_DRUPAL # even for WPML...
    self.client ||= Client.anon_client(cms_kind)
  end

  def set_affiliate(id, key)
    return unless client.anon?
    affiliate = User.find_by(id: id)
    if affiliate && (affiliate.affiliate_key == key)
      self.client.affiliate = affiliate
      self.client.save
    end
  end

  def valid_platform_kind
    if platform_kind == 0
      errors.add(:platform_kind, _('must be selected'))
    elsif platform_kind == WEBSITE_WORDPRESS
      errors.add(:login, _('cannot be blank')) if login.blank?
      errors.add(:password, _('cannot be blank')) if password.blank?
    end
  end

  def old_accesskey
    if client && client.full_real_name
      Digest::MD5.hexdigest(id.to_s + client.full_real_name)
    else
      '--- accesskey cannot be calculated for this website ---'
    end
  end

  def send_translated_message(web_message)
    ok = false
    if (platform_kind == WEBSITE_DRUPAL) && (pickup_type == PICKUP_BY_RPC_POST)
      server = get_server

      if server
        signature = Digest::MD5.hexdigest(accesskey + id.to_s + web_message.id.to_s) # "%s%i%i" % (access_key, website_id, request_id)
        res = 'not delivered'
        if Rails.env != 'test'
          begin
            res = server.call('icanlocalize.notify_comment_translation', signature, id, web_message.id, web_message.client_body)
          rescue
            logger.info "--------- SEND_TRANSLATED_MESSAGE: web_message.#{web_message.id}: HOST NOT CONTACTED"
          end
        else
          res = 1
        end
        logger.info "--- XML-RPC: icanlocalize.notify_comment_translation(#{signature}, #{id}, #{web_message.id}, #{web_message.client_body}) - result: #{res}"
        ok = (res == 1)
      else
        logger.info "--------- SEND_TRANSLATED_MESSAGE: web_message.#{web_message.id}: HOST NOT FOUND IN #{url}"
      end

    end

    ok

  end

  def can_delete?
    (cms_requests.count == 0) && (web_messages.count == 0)
  end

  def can_link?
    (pickup_type == PICKUP_BY_RPC_POST)
  end

  # Are any of this website's language pairs which contain pending CmsRequests
  # ready to receive payment from the client?
  def client_can_pay_any_language_pair?
    pending_language_pairs.any?(&:client_can_pay?)
  end

  # Are all of this website's language pairs ready to receive payment from the
  # client?
  def client_can_pay_all_language_pairs?
    pending_language_pairs.all?(&:client_can_pay?)
  end

  # Pending CmsRequests that belong to language pairs that are ready to receive
  # payment from the client.
  def payable_cms_requests
    # TODO: Refactor to improve performance (reduce number of queries)
    payable_language_pairs = website_translation_offers.select(&:client_can_pay?)
    # Return an ActiveRecord::Relation object
    payable_cms_request_ids = payable_language_pairs.map(&:processed_pending_cms_requests).flatten.map(&:id)
    CmsRequest.where(id: payable_cms_request_ids)
  end

  # This method solves the following scenario which used to be an issue:
  # 1. Client adds contents for 1 language pair with automatic translator,
  #    costing $10
  # 2. Client pays $10
  # 3. Before a translator starts working on the first language pair (before the
  #    money is moved to an escrow account and CmsTargetLanguage status is
  #    changed from 0 to 1), the client adds 1 more language pair with automatic
  #    translator assignment which costs another $10.
  # 4. Website#missing_amount returns 0 when it should return 10, because the
  #    $10 that the client paid is still in his account. So, it appears to the
  #    client that he has enough funds for both language pairs and no additional
  #    payment is asked. Somewhere along the line, translators will not be able
  #    to start working on some CmsRequests because of lacking funds.
  #
  # Now, when a client pays for translation jobs:
  # 1. The payment processor sends us a payment confirmation and the money is
  # added to the client's ICL account.
  # 2. Immediately after the money is added to his ICL account, we call
  # PendingMoneyTransaction.reserve_money_for_cms_requests to remove the
  # money from the client's account balance and place it on "hold", so it can't
  # be used for anything else (doesn't even appear on the client's balance).
  # 3. When a translator starts working on a specific cms_request,
  # CmsRequestsController#assign_to_me moves the amount of money required to pay
  # for that cms_request from the "hold" to an escrow account (a BidAccount
  # record).
  def reserve_money_for_cms_requests(paid_cms_requests)
    raise ArgumentError, 'Expected to receive at least one cms_request' if paid_cms_requests.blank?
    # All cms_requests must belong to this website
    raise ArgumentError, 'Received cms_requests from different websites' if \
      paid_cms_requests.pluck(:website_id).uniq != [id]

    # We will create one PEndingMoneyTransaction record for each paid CmsRequest.
    # But how do we know which CmsRequests were paid for? There are two scenarios:
    #
    # Scenario 1) The client does not have enough funds in his ICL account:
    # In the new flow, when a client pays, before he is redirected to Paypal,
    # an Invoice record is created. The client can't choose to pay for some
    # cms_requests but not others (he must pay the full amount of the invoice),
    # wo we can be sure that all cms_requests of language pairs that are currently
    # "payable" (see WebsiteTranslationOffer#client_can_pay?) were paid for.
    # Those cms_requests are associated with the invoice
    # (Invoice has_many cms_requests). When the payment processor sends us a
    # confirmation of successful payment for a specific invoice, we know all
    # cms_requests associated to that invoice are paid for. Than we move their
    # total amount to the "hold" balance.
    # Associating the cms_requests with the invoice is necessary because the
    # payment confirmation from PayPal may take up to 48 hours and the client,
    # may send more contents for translation in this meantime, so we must know,
    # exactly which cms_requests were "payable" (hence, were paid for) at the
    # time the invoice was generated.
    #
    # Scenario 2) The client has enough funds in his ICL account to pay for
    # all pending cms_requests (all cms_requests of all "payable" language pairs):
    # When the client clicks the "Pay" button, he is not redirected to a payment
    # processor such as paypal. Instead, he "pays" with his ICL account balance.
    # There is no invoice here, but the client can't choose to pay for some
    # cms_requests but not others, so we can be sure that all cms_requests of
    # language pairs that are "payable" (see WebsiteTranslationOffer#client_can_pay?)
    # at the time the client clicks the "pay" button will be paid for with his
    # ICL account balance.
    PendingMoneyTransaction.reserve_money_for_cms_requests(paid_cms_requests)
  end

  # Last time the client paid for translation jobs within this website
  def last_payment_received_at
    PendingMoneyTransaction.where(owner: cms_requests).maximum(:created_at)
  end

  # Has this website ever received a payment from the client
  def any_payment_received?
    !!last_payment_received_at
  end

  def last_job_sent_at
    cms_requests.maximum(:created_at)
  end

  # Check if all language pairs set to manual translator assignment already have
  # translators assigned (the client accepted at least one translator
  # application for each of those language pairs)
  def any_pending_manual_translator_assignments?
    !pending_language_pairs.
      where(automatic_translator_assignment: false).
      all?(&:any_translators_accepted?)
  end

  def pending_language_pairs
    pending_wto_ids = website_translation_offers.select(&:any_pending_cms_requests?).map(&:id)
    # Return an ActiveRecord::Relation object, not an array
    WebsiteTranslationOffer.where(id: pending_wto_ids)
  end

  def pending_processed_language_pairs
    pending_wto_ids = website_translation_offers.select(&:any_processed_pending_cms_requests?).map(&:id)
    WebsiteTranslationOffer.where(id: pending_wto_ids)
  end

  def any_pending_language_pairs?
    pending_language_pairs.size > 0
  end

  def any_pending_processed_language_pairs?
    pending_processed_language_pairs.size > 0
  end

  # Do any language pairs require user action (e.g., select translators or pay)
  # in order to be translated?
  def user_action_required?
    any_pending_processed_language_pairs?
  end

  # Returns true if there are one or more associated unfunded
  # website_translation_offers with automatic translator assignment disabled.
  def any_manual_translator_assignment?
    pending_language_pairs.any? { |wto| !wto.automatic_translator_assignment }
  end

  # Returns true if any content was ever sent for translation by WPML
  def any_content_sent_for_translation?
    website_translation_offers.size > 0
  end

  # Does any language pair can have it's translator assignment mode changed
  # (between manual and automatic) by the client? If all language pairs already
  # received at least one payment, their translation assignment mode can't be
  # changed.
  def can_change_any_translator_assignment_mode?
    pending_language_pairs.any?(&:can_change_translator_assignment_mode?)
  end

  def get_server
    if !xmlrpc_path.blank?
      uri = URI.parse(xmlrpc_path)
      host = uri.host
      path = uri.path
    else
      uri = URI.parse(url)
      host = uri.host

      path = uri.path
      path += '/' if path[-1..-1] != '/'
      path += 'xmlrpc.php'
    end

    return nil unless host

    client = XMLRPC::Client.new(host, path, 80)
    client.http_header_extra = { 'User-Agent' => XMLRPC_USER_AGENT }
    client
  end

  def to_languages
    cms_target_languages.map(&:language).uniq
  end

  # TODO: It seems like this method is not called anywhere. Confirm that and remove the method.
  def has_managed_work_for(language_pair)
    wtos = website_translation_offers.find_all do |wto|
      wto.from_language == language_pair.from_language
      (wto.to_language == language_pair.to_language) &&
        wto.managed_work &&
        wto.managed_work.active
    end
    wtos.any?
  end

  def open_issues
    cms_requests.map do |x|
      x.revision &&
        x.revision.revision_languages &&
        x.revision.revision_languages.first &&
        x.revision.revision_languages.first.issues
    end.flatten.find_all { |x| x && (x.status == ISSUE_OPEN) }
  end

  def find_or_create_offer(from_language, to_language)
    offer = website_translation_offers.where('(from_language_id=?) AND (to_language_id=?)', from_language.id, to_language.id).first

    # When automatic translator assignment is enabled, the language pair should
    # not be visible for translators to apply.
    status = if anon == 1 || offer&.automatic_translator_assignment
               TRANSLATION_OFFER_CLOSED
             else
               TRANSLATION_OFFER_OPEN
             end

    if offer
      if offer.status == TRANSLATION_OFFER_SUSPENDED
        offer.update_attributes(status: status)
      end
    else
      offer = WebsiteTranslationOffer.new(website_id: id,
                                          from_language_id: from_language.id,
                                          to_language_id: to_language.id,
                                          url: url,
                                          login: login,
                                          password: password,
                                          status: status,
                                          # Older versions of WPML do not support automatic translator assignment
                                          automatic_translator_assignment: icl_v2_translation_service?)

      offer.managed_work = ManagedWork.create(
        active: MANAGED_WORK_INACTIVE,
        from_language_id: from_language.id,
        to_language_id: to_language.id,
        client: client
      )
      offer.notified = 0
      offer.save!
    end

    offer
  end

  def enabled_shortcodes
    global_shortcodes = Shortcode.global.to_a.delete_if { |s| !s.enabled_for_website? id }
    shortcodes.enabled + global_shortcodes
  end

  def pending_tas_requests
    cms_requests.where('pending_tas = ?', true).all
  end

  def resign_from_translating(user, remarks = '')
    WebsiteTranslationContract.resign_all_website_contract(user, self, remarks)
  end

  def resign_from_reviewing(user, remarks = '')
    ManagedWork.resign_all_website_reviews(user, self, remarks)
  end

  def resign_from_this_website(user, remarks = '')
    raise 'Please explain why you want to resign from this website' unless remarks.present?
    resign_from_translating(user)
    resign_from_reviewing(user)
  end

  def reverse_api_version
    new_api_version = if self.api_version.nil? || self.api_version == '1.0'
                        '2.0'
                      else
                        '1.0'
                      end
    self.update_attribute(:api_version, new_api_version)
    self.reload
  end

  # In the "Translators" tab of WPML < 3.9, the client can choose between
  # "ICL v1" (legacy) and "ICL v2" translation services. As of WPML 3.9, he can
  # only use "ICL v2". The main difference is that With ICL v1, the client must
  # choose a translator in WPML before sending contents to ICL. In ICL v2,
  # there is no way to choose a translator in WPML, only in ICL. Also, ICL v1
  # does not support automatic translator assignment.
  def icl_v2_translation_service?
    api_version == '2.0'
  end

  def has_wp_credentials?
    self.encrypted_wp_username.present? || self.encrypted_wp_password.present? || self.wp_login_url.present?
  end

  def encrypt_wp_credentials
    self.encrypted_wp_username = encrypt(wp_username) if wp_username.present?
    self.encrypted_wp_password = encrypt(wp_password) if wp_password.present?
  end

  def encryptor
    ActiveSupport::MessageEncryptor.new(Rails.application.secrets.secret_key_base)
  end

  def encrypt(str)
    encryptor.encrypt_and_sign(str)
  end

  def decrypt(encrypted_str)
    encryptor.decrypt_and_verify(encrypted_str)
  end

  %w(wp_username wp_password).each do |attribute|
    define_method(attribute) do
      instance_variable_get("@#{attribute}") || instance_variable_set("@#{attribute}", send("encrypted_#{attribute}") ? decrypt(send("encrypted_#{attribute}")) : nil)
    end

    define_method("#{attribute}=") do |value|
      instance_variable_set("@#{attribute}", value)
    end
  end

  # Checks if all translation jobs of this website are completed (including
  # reviews).
  def completed?
    cms_requests.all? { |cms| cms.status == CMS_REQUEST_DONE }
  end

  def can_create_testimonial?
    self.testimonial.nil? && self.completed?
  end

  def create_testimonial(params)
    raise 'Testimonial already exists' unless self.testimonial.nil?
    raise 'Job not done yet' unless self.completed?
    params[:owner] = self
    Testimonial.create(owner: self,
                       testimonial: params[:testimonial],
                       link_to_app: params[:link_to_app],
                       testimonial_by: params[:testimonial_by],
                       rating: params[:rating])
  end

  # Exceptions
  class NotFound < JSONError
    def initialize
      @code = WEBSITE_NOT_FOUND
      @message = 'Cannot find website'
    end
  end

  class NotCreated < JSONError
    def initialize(website)
      @code = WEBSITE_NOT_CREATED
      @message = website.errors.full_messages.join(', ')
      @http_status_code = 422
    end
  end

end
#
