# Attributes:
# - api_key: Clients insert the API key in WPML, which sends it to TP, which
# in turn uses it to perform requests to the ICL API.
class Client < NormalUser
  has_many :websites, dependent: :destroy
  has_many :website_translation_offers, through: :websites
  has_many :projects, dependent: :destroy
  has_many :revisions, through: :projects
  has_many :captcha_keys, dependent: :destroy
  has_many :web_supports, dependent: :destroy
  has_many :web_messages, as: :owner, dependent: :destroy

  has_many :cms_requests, through: :websites

  has_many :error_cms_requests,
           -> {
             where('((cms_requests.pending_tas=1) OR (cms_requests.status IN (?))) AND (cms_requests.updated_at < ?)',
                   [
                     CMS_REQUEST_WAITING_FOR_PROJECT_CREATION,
                     CMS_REQUEST_PROJECT_CREATION_REQUESTED,
                     CMS_REQUEST_CREATING_PROJECT
                   ],
                   Time.now - TAS_PROCESSING_TIME)
           },
           through: :websites,
           source: :cms_requests,
           class_name: 'CmsRequest'

  has_many :private_translators, dependent: :destroy
  has_many :all_private_translators, through: :private_translators, source: :translator, class_name: 'Translator'

  has_many :accepted_private_translators,
           -> { where('private_translators.status=?', PRIVATE_TRANSLATOR_ACCEPTED) },
           through: :private_translators,
           source: :translator,
           class_name: 'Translator'

  has_many :text_resources, dependent: :destroy
  has_many :resource_chats, through: :text_resources
  has_many :resource_languages, through: :text_resources

  has_many :glossary_terms, dependent: :destroy
  has_many :glossary_translations, through: :glossary_terms

  has_many :managed_works, dependent: :destroy

  has_many :tus, dependent: :destroy

  has_and_belongs_to_many :vouchers, join_table: :clients_vouchers

  # new TM for WebTA
  has_many :translation_memories
  has_many :translated_memories, through: :translation_memories

  # Do not require an api_key for subclasses of Client such as Alias
  validates :api_key, presence: true, if: 'self.class == Client'

  # Do not create an api_key for subclasses of Client such as Alias
  before_validation :set_api_key, if: ['new_record?', 'self.class == Client']

  before_create :set_signup_date

  def self.anon_client(cms_kind)
    # Milliseconds since epoch
    unique_digits = (Time.now.to_f * 1000).to_i
    create!(email: "unreg#{unique_digits}@icanlocalize.com",
            signup_date: Time.now,
            fname: "fname#{unique_digits}",
            lname: "lname#{unique_digits}",
            nickname: "unreg#{unique_digits}",
            password: "pw#{unique_digits}",
            anon: 1,
            notifications: NEWSLETTER_NOTIFICATION,
            display_options: DISPLAY_AFFILIATE,
            source: "CMS #{CMS_DESCRIPTION[cms_kind]}")
  end

  def has_completed_projects?
    has_completed_text_resources? || has_completed_websites?
  end

  def self.should_receive_logo
    Client.where('users.userstatus != ? and users.sent_logo = ?')
  end

  def minimum_bid_amount
    if top
      amount = MINIMUM_BID_AMOUNT * TOP_CLIENT_DISCOUNT
      (amount * 100).truncate / 100.0
    else
      MINIMUM_BID_AMOUNT
    end
  end

  def valid_text_resources
    text_resources.where(
      "EXISTS (SELECT id FROM resource_languages WHERE resource_languages.text_resource_id = text_resources.id) AND
       EXISTS (SELECT id FROM resource_strings WHERE resource_strings.text_resource_id = text_resources.id)"
    )
  end

  def has_completed_text_resources?
    return false unless valid_text_resources.any?

    uncompleted_text_resources_count =
      text_resources.
      joins(:string_translations).
      where(
        "string_translations.status != ? OR string_translations.review_status NOT IN (?) AND
         EXISTS (SELECT id FROM resource_languages WHERE resource_languages.text_resource_id = text_resources.id) AND
         EXISTS (SELECT id FROM resource_strings WHERE resource_strings.text_resource_id = text_resources.id)",
        STRING_TRANSLATION_COMPLETE, [REVIEW_NOT_NEEDED, REVIEW_COMPLETED]
      ).count

    uncompleted_text_resources_count == 0
  end

  def has_completed_websites?
    ret = false
    websites.each do |website|
      if website.cms_requests.any? && website.cms_requests.where('status not in (?)', [CMS_REQUEST_DONE, CMS_REQUEST_FAILED]).first.nil?
        ret = true
        break
      end
    end
    ret
  end

  def verified?
    true
  end

  def can_deposit?
    true
  end

  def can_pay?
    true
  end

  def can_view_finance?
    true
  end

  def users_to_switch
    []
  end

  def translator_is_reviewer?(object, translator)
    (object.managed_work && (object.managed_work.active == MANAGED_WORK_ACTIVE) && (object.managed_work.translator == translator))
  end

  def bidding_projects
    revisions.where('revisions.cms_request_id IS NULL').limit(PER_PAGE_SUMMARY).order('revisions.id DESC').includes(:project)
  end

  def open_jobs(translator)
    # bidding jobs
    # website_translation_offers
    # software localization
    # open review positions

    # [from_lang,to_lang]=>job

    # check the translator's languages
    from_lang_ids = translator.from_languages.collect(&:id)
    to_lang_ids = translator.to_languages.each(&:id)

    if translator.private_translator?
      from_lang_ids = (1..Language.count).to_a
      to_lang_ids = (1..Language.count).to_a
    elsif from_lang_ids.empty? || to_lang_ids.empty?
      return {}
    end

    res = {}

    # --- translation jobs ---

    open_revisions = revisions.where('(language_id IN (?)) AND (released = 1) AND (UNIX_TIMESTAMP(bidding_close_time) > ?)', from_lang_ids, Time.now.to_i)
    open_revisions.each do |revision|
      next if revision.chats.where(translator_id: translator.id).first
      revision.revision_languages.where('language_id IN (?)', to_lang_ids).find_each do |rl|
        if !rl.selected_bid && !translator_is_reviewer?(rl, translator)
          add_job(res, revision.language, rl.language, rl)
        end
      end
    end

    website_translation_offers.where('(website_translation_offers.from_language_id IN (?)) AND (website_translation_offers.to_language_id IN (?)) AND (website_translation_offers.status=?)', from_lang_ids, to_lang_ids, TRANSLATION_OFFER_OPEN).find_each do |website_translation_offer|
      if !website_translation_offer.website_translation_contracts.where(translator_id: translator.id).first && !translator_is_reviewer?(website_translation_offer, translator)
        add_job(res, website_translation_offer.from_language, website_translation_offer.to_language, website_translation_offer)
      end
    end

    resource_languages.joins(:text_resource).
      where('(text_resources.language_id IN (?)) AND (resource_languages.language_id IN (?))', from_lang_ids, to_lang_ids).find_each do |resource_language|

      if !resource_language.resource_chats.where(translator_id: translator.id).first && !translator_is_reviewer?(resource_language, translator)
        add_job(res, resource_language.text_resource.language, resource_language.language, resource_language)
      end
    end

    # --- review jobs ---
    if (translator.level == EXPERT_TRANSLATOR) && [USER_STATUS_REGISTERED, USER_STATUS_QUALIFIED].include?(translator.userstatus)

      managed_works.where(
        '(managed_works.from_language_id IN (?)) AND (managed_works.to_language_id IN (?)) AND (managed_works.active=?) AND (managed_works.translator_id IS NULL)',
        from_lang_ids,
        to_lang_ids,
        MANAGED_WORK_ACTIVE
      ).find_each do |managed_work|

        if ((managed_work[:owner_type] != 'RevisionLanguage') || !managed_work.owner.revision.cms_request) &&
           (managed_work.blocked_translators.nil? || !managed_work.blocked_translators.include?(translator))
          add_job(res, managed_work.from_language, managed_work.to_language, managed_work)
        end
      end
    end

    res

  end

  def add_job(res, from_lang, to_lang, job)
    key = [from_lang, to_lang]
    res[key] = [] unless res.key?(key)
    res[key] << job
  end

  def need_ta?
    revisions.where('(revisions.kind=?) AND (revisions.cms_request_id IS NULL)', TA_PROJECT).exists?
  end

  def transfer_from_other_user(temp_user)
    return if self == temp_user

    # now, transfer everything from the temporary user to the right user

    # 1. money accounts - create and transfer the payment from the external account
    account = find_or_create_account(DEFAULT_CURRENCY_ID)

    # 2. invoices
    temp_user.invoices.each do |invoice|
      invoice.user = self
      invoice.save!
      # MoneyTransactionProcessor.transfer_money(external_account, account, invoice.gross_amount, invoice.currency_id, TRANSFER_DEPOSIT_FROM_EXTERNAL_ACCOUNT)
    end

    # 3. money accounts
    temp_user.money_accounts.each do |temp_account|
      temp_account.credits.each do |credit|
        credit.target_account = account
        credit.save!
      end
      temp_account.account_lines.each do |account_line|
        account_line.account = account
        account_line.save!
      end
    end

    # 4. web messages
    temp_user.web_messages.each do |web_message|
      web_message.user = self
      web_message.owner = self
      web_message.money_account = account
      web_message.save!
    end

    save!

    # 5. messages
    temp_user.messages.each do |message|
      message.user = self
      message.save
    end

    # 6. websites
    temp_user.websites.each do |website|
      website.client = self
      website.save
    end

    # discard the temporary user
    temp_user.reload
    User.delete(temp_user.id)

    reload
  end

  def has_projects?
    !websites.empty? || !projects.empty? || !web_messages.empty? || !text_resources.empty?
  end

  def web_messages_pending_translation(extra_sql = nil)
    web_messages.
      includes(:money_account).
      where("(web_messages.translation_status = ?) #{extra_sql}", TRANSLATION_NEEDED)
  end

  # TODO: remove extra_sql. spetrunin 10/18/2016
  def web_messages_pending_review(extra_sql = nil)
    web_messages.
      includes(:money_account).
      joins(:managed_work).
      where(
        "web_messages.translation_status in (?) and
        managed_works.translation_status in (?)
        #{extra_sql}",
        [TRANSLATION_NEEDED, TRANSLATION_COMPLETE], [MANAGED_WORK_CREATED, MANAGED_WORK_REVIEWING]
      )
  end

  def unfunded_web_messages
    imsgs = web_messages.where(translation_status: TRANSLATION_NEEDED)
    imsgs.select { |x| x.has_enough_money_for_translation? == false }
  end

  # Alias overwrited methods
  def can_create_projects?(_website = nil)
    true
  end

  def should_update_vat_information?
    (vat_number.nil? || vat_number.blank?) && ( # Doesnt has VAT number AND...
        country_pay_taxes? || # has a country, and belongs to EU OR..
        ((country_id.blank? || country_id.zero?) && ip_country_pay_taxes?) # has no country, and ip is in EU
    )
  end

  def ip_country_pay_taxes?
    Country.require_vat_list.include? last_ip_country_id
  end

  def country_pay_taxes?
    Country.require_vat_list.include? country_id
  end

  # Do request to VIES ws to validate vat number of a uses
  def check_if_vat_is_business
    self.is_business_vat = nil
    Rails.logger.info "Validating VAT Number #{full_vat_number}..."

    unless vat_number.empty?
      require 'eurovat'
      begin
        self.is_business_vat = Eurovat.check_vat_number(full_vat_number)
      rescue Savon::SOAPFault => e
        Rails.logger.info 'VAT CHECKING SERVICE IS NOT AVAILABLE FOR ' + full_vat_number
        if e.message == 'MS_UNAVAILABLE'
          save
          return false
        end
      rescue Exception => e
        Rails.logger.info 'GENERAL ERROR WHILE CHECKING VAT FOR ' + full_vat_number
      end
    end
    Rails.logger.info "Validating Result: #{is_business_vat}"
    save
  end

  def full_vat_number
    "#{country.try(:tax_code)}#{vat_number}"
  end

  # @ToDo Refactor: When this method is used we are using a math function to calculate tax rate,
  # refactor that (this method is ok, but is helpful to track where the refactor is needed)
  def has_to_pay_taxes?
    if country_pay_taxes?
      return false if exception_to_taxes
      return true if vat_number.nil? || vat_number.blank?
      # Check VAT if is nil, after checked it have to be 0 or 1
      check_if_vat_is_business
      return true unless is_business_vat
    end

    false
  end

  def calculate_tax(amount)
    return 0 unless has_to_pay_taxes?
    # PayPal takes invoice.gross_amount and invoice.tax_rate as parameters,
    # calculates the tax amount (rounding with floor and not ceil) and adds it
    # to the payment. Se we must use floor here too, or else our tax calculation
    # will be 1 cent greater than PayPal's calculation.
    ((amount * country.tax_rate) / 100).floor_money
  end

  def tax_rate
    if has_to_pay_taxes?
      country.tax_rate
    else
      0
    end
  end

  def total_deposited
    money_account.money_transactions.where('money_transactions.source_account_type = ? ', 'ExternalAccount').sum(:amount)
  end

  def is_allowed_to_withdraw?
    if allowed_to_withdraw.nil?
      money_account.balance <= (total_deposited * 0.2)
    else
      allowed_to_withdraw
    end
  end

  def allow_to_withdraw!(how_many_times = 1)
    update_attribute :allowed_to_withdraw, how_many_times
  end

  def exception_to_taxes
    # Canary Islands don't pay taxes
    return false unless zip_code
    country.try(:name) == 'Spain' && %w(35 38 51 52).any? { |i| zip_code.starts_with? i }
  end

  def confirm_email!
    self.userstatus = USER_STATUS_REGISTERED
  end

  def pending_amount(what = 'CmsRequest')
    # this methods calculates how much money are already in PendingMoneyTransaction to not duplicate them in planned_expenses
    query = "select sum(p.amount) from users as u
                inner join websites as w on u.id = w.client_id
                inner join cms_requests as c on w.id = c.website_id
                right outer join pending_money_transactions as p on c.id = p.owner_id and p.owner_type='#{what}' and deleted_at is NULL
                where u.id = #{self.id}
                group by u.id
             "
    ActiveRecord::Base.connection.execute(query).to_a[0].try(:first) || 0
  end

  def complete_all_sandbox
    return unless Rails.env.sandbox? || Rails.env.development?
    self.websites.each do |w|
      w.cms_requests.where('status= ? or status=?', 4, 5).find_each do |cms|
        xliff = cms.xliffs.last
        next if xliff.nil?
        xliff.translated = true
        xliff.save!
        cms.status = 6
        cms.save!
      end
    end
  end

  # Returns websites that require actions from the client (inviting/accepting
  # translators and/or paying)
  def websites_requiring_client_action
    websites.select(&:user_action_required?)
  end

  private

  def set_api_key
    return unless api_key.blank?
    self.api_key = SecureRandom.uuid
  end

  def set_signup_date
    return if signup_date.present?
    self.signup_date = Time.now
  end
end
