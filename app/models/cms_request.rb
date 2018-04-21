# 	status:		* please note that status that appear on cms_request#show comes from cms_target_language
# 		CMS_REQUEST_CREATING = 0
# 		CMS_REQUEST_WAITING_FOR_PROJECT_CREATION = 1
# 		CMS_REQUEST_PROJECT_CREATION_REQUESTED = 2
# 		CMS_REQUEST_CREATING_PROJECT = 3
# 		CMS_REQUEST_RELEASED_TO_TRANSLATORS = 4
#       Job is released to translators. CmsRequestsController#release (called
#       by TAS) and CmsRequestsController#update_status (called by WebTA) both
#       set this status when they're finished processing the CmsRequest (amongst
#       other methods).
# 		CMS_REQUEST_TRANSLATED = 5
#       Status 5 means translation is completed. If review is disabled,
#       it's waiting to be delivered. If review is enabled, it's waiting to be
#       reviewed ;
# 		CMS_REQUEST_DONE = 6
#       Status 6 means the translation was delivered to TP
#       (CmsRequestsController#notify_cms_delivery was called by TP).
# 		CMS_REQUEST_FAILED = 7
# 		CMS_REQUEST_MARKED_FOR_CANCEL = 8
#
# 	last_operation:
# 		LAST_TAS_COMMAND_CREATE = 1
# 		LAST_TAS_COMMAND_OUTPUT = 2
#
# 	CmsRequest is a job for website translation.
# 		WPML =< 3.1
# 			c.cms_uploads: source file
# 			c.cms_target_language.cms_downloads: target files
# 		TP:
# 			c.xliffs: have both source and target file.
#
# 	Word counts:
# 		WC appears in:
# 			Revision:
# 				c.revision.version.statistics
# 				To get an human readable hash with stats (wc)
# 					c.revision.get_human_stats
# 				To update statistics:
# 					c.revision.get_last_client_version.update_statistics
# 			c.word_count
# 				This values comes from TP (from WPML), is just for reference
# 			CmsTargetLanguage.word_count
# 				Is the same number that appear on revision, this is used for billing
#

require 'base64'

class CmsRequest < ApplicationRecord
  belongs_to :website
  belongs_to :language
  # Invoice regarding the payment of this translation job by the client. Beware
  # that having an invoice does not mean this CmsRequest is paid for, you must
  # look a the invoice status to see if the payment was successful.
  belongs_to :invoice, optional: true

  has_one :cms_target_language, dependent: :destroy
  has_one :translator, through: :cms_target_language
  has_one :revision, dependent: :destroy
  # Between the time that a cms_request is paid for and the amount is moved to an
  # escrow account, the amount stays in the client's "hold_sum" and has a
  # corresponding pending_money_transaction record. If the cms_request is
  # deleted, a before_destroy callback releases that money and destroys the
  # associated pending_money_transaction.
  has_one :pending_money_transaction, as: :owner

  has_many :cms_uploads, foreign_key: :owner_id, dependent: :destroy
  has_many :cms_target_languages, dependent: :destroy
  has_many :comm_errors, dependent: :destroy
  has_many :sent_notifications, as: :owner, dependent: :destroy
  has_many :cms_request_metas, dependent: :destroy
  has_many :xliffs, dependent: :destroy
  has_many :languages, through: :cms_target_languages
  has_many :xliff_trans_unit_mrks, dependent: :destroy
  has_many :mrk_issues, through: :xliff_trans_unit_mrks, source: :issues, dependent: :destroy
  # for webta and TM, this is the xliff parsed and saved in DB
  has_many :parsed_xliffs, dependent: :destroy
  has_many :tmt_configs

  validates_presence_of :language_id
  # Custom validations
  validate :review_enabled_validation

  before_destroy :cleanup_before_destroy

  STATUS_TEXT = {
    CMS_REQUEST_CREATING => N_('Processing'),
    CMS_REQUEST_WAITING_FOR_PROJECT_CREATION => N_('Processing'),
    CMS_REQUEST_PROJECT_CREATION_REQUESTED => N_('Processing'),
    CMS_REQUEST_CREATING_PROJECT => N_('Processing'),
    CMS_REQUEST_RELEASED_TO_TRANSLATORS => N_('Not translated yet'),
    CMS_REQUEST_TRANSLATED => N_('Translation received'),
    CMS_REQUEST_DONE => N_('Translation completed')
  }.freeze

  LAST_COMMAND_TEXT = {
    LAST_TAS_COMMAND_CREATE => N_('Fetch contents from website'),
    LAST_TAS_COMMAND_OUTPUT => N_('Return translations to website')
  }.freeze

  scope :paid, lambda {
    where('cms_requests.status IN (?)', [
            CMS_REQUEST_RELEASED_TO_TRANSLATORS,
            CMS_REQUEST_TRANSLATED,
            CMS_REQUEST_DONE
          ])
  }

  def self.error_requests(time = nil)
    CmsRequest.where('((pending_tas=1) OR (cms_requests.status IN (?))) AND (updated_at < ?)', [CMS_REQUEST_WAITING_FOR_PROJECT_CREATION, CMS_REQUEST_PROJECT_CREATION_REQUESTED, CMS_REQUEST_CREATING_PROJECT], (time || Time.now) - TAS_PROCESSING_TIME)
  end

  def self.incomplete_requests
    CmsRequest.eager_load(:cms_target_languages).includes(website: :client).where('cms_target_languages.status != ?', CMS_TARGET_LANGUAGE_DONE)
  end

  def self.stuck_requests
    cms_requests = CmsRequest.includes(:comm_errors).where(pending_tas: 1)
    res = []
    cms_requests.each do |cms_request|
      if cms_request.comm_errors.where('comm_errors.status=?', COMM_ERROR_ACTIVE).count >= MAX_COMM_ERRORS
        res << cms_request
      end
    end
    res
  end

  def self.review_usage_report(start_date = nil, end_date = nil)
    sql = %{
        SELECT
          source_language.name as base_language,
          target_language.name as target_language,
          COUNT(*) as jobs_total,
          COUNT(CASE
              WHEN cms_requests.review_enabled IS NULL AND mw.active = #{MANAGED_WORK_ACTIVE} THEN 1
              WHEN cms_requests.review_enabled IS TRUE THEN 1
          END
          ) AS review_enabled_total,
          COUNT(CASE
              WHEN cms_requests.review_enabled IS NULL AND mw.active = #{MANAGED_WORK_INACTIVE} THEN 1
              WHEN cms_requests.review_enabled IS NULL AND mw.active IS NULL THEN 1
              WHEN cms_requests.review_enabled IS FALSE THEN 1
          END
          ) AS review_disabled_total
        FROM cms_requests
          LEFT OUTER JOIN cms_target_languages ON cms_requests.id = cms_target_languages.cms_request_id
          LEFT OUTER JOIN languages AS source_language ON cms_requests.language_id = source_language.id
          LEFT OUTER JOIN languages AS target_language ON cms_target_languages.language_id = target_language.id
          LEFT OUTER JOIN revisions as rev ON rev.cms_request_id = cms_requests.id
          LEFT OUTER JOIN revision_languages as rev_lang ON rev.id = rev_lang.revision_id
          LEFT OUTER JOIN managed_works as mw ON rev_lang.id = mw.owner_id AND mw.owner_type = 'RevisionLanguage'
        WHERE EXISTS (SELECT 1 FROM pending_money_transactions AS pmt WHERE pmt.owner_id = cms_requests.id AND pmt.owner_type = 'CmsRequest')
        AND cms_target_languages.language_id IS NOT NULL
    }
    if start_date.present? && end_date.present?
      sql += " AND DATE(cms_requests.created_at) BETWEEN '#{start_date}' AND '#{end_date}'"
    end
    sql += ' GROUP BY base_language, target_language ORDER BY jobs_total DESC'

    CmsRequest.find_by_sql(sql)
  end

  def self.unstarted_auto_assignment_jobs
    twenty_four_hours_ago = 24.hours.ago.utc.to_s(:db)

    sql = <<-SQL
      SELECT DISTINCT cms_requests.*,
      website_translation_contracts.id as wtc_id,
      GREATEST(cms_requests.created_at, website_translation_contracts.accepted_by_client_at) as assigned_at
      FROM cms_requests
        INNER JOIN cms_target_languages ON cms_target_languages.cms_request_id = cms_requests.id
        INNER JOIN websites ON websites.id = cms_requests.website_id
        INNER JOIN website_translation_offers ON website_translation_offers.website_id = websites.id
          AND cms_target_languages.language_id = website_translation_offers.to_language_id
        INNER JOIN website_translation_contracts ON website_translation_contracts.website_translation_offer_id = website_translation_offers.id
        INNER JOIN pending_money_transactions pmt ON pmt.owner_id = cms_requests.id AND pmt.owner_type = 'CmsRequest'
      WHERE
        cms_requests.status = 4
        AND cms_target_languages.status = 0
        AND cms_requests.created_at < "#{twenty_four_hours_ago}"
        AND website_translation_contracts.accepted_by_client_at < "#{twenty_four_hours_ago}"
        AND website_translation_contracts.status = 2
        AND website_translation_offers.automatic_translator_assignment IS TRUE
      ORDER BY assigned_at ASC;
    SQL

    CmsRequest.find_by_sql(sql)
  end

  def self.unfinished_translation_jobs
    query = <<-SQL
      SELECT DISTINCT cms_requests.*
      FROM cms_requests
        INNER JOIN cms_target_languages
          ON cms_target_languages.cms_request_id = cms_requests.id
        INNER JOIN users
          ON users.id = cms_target_languages.translator_id AND users.type IN ('Translator')
        INNER JOIN pending_money_transactions AS pmt
          ON cms_requests.id = pmt.owner_id AND pmt.owner_type = 'CmsRequest'
      WHERE cms_requests.deadline IS NOT NULL AND cms_requests.status < 5
      ORDER BY cms_requests.deadline DESC;
    SQL

    CmsRequest.find_by_sql(query)
  end

  # Check if a specific translator is authorized to view this CmsRequest
  # Translators can only see the CmsRequests of the language pairs they were
  # assigned/accepted in a given website.
  def translator_can_view?(translator)
    website_translation_offer&.
      accepted_website_translation_contracts&.
      where(translator: translator)&.
      any? || false
  end

  # There can be only one WebsiteTranslationOffer per language pair per website,
  # so any CmsRequest+CmsTargetLanguage with a given language pair is related
  # to the one and only WebsiteTranslationOffer of that same language pair for
  # its website.
  def website_translation_offer(target_language = nil)
    target_language ||= cms_target_language&.language
    raise(ArgumentError, 'A source language is required to find a WebsiteTranslationOffer') if language.nil?
    raise(ArgumentError, 'A target language is required to find a WebsiteTranslationOffer') if target_language.nil?
    return unless website&.website_translation_offers.present?

    website.website_translation_offers.where(
      from_language: language,
      to_language: target_language
    ).first
  end

  def retry_tas
    NotifyTas.retry_cms_request self
  end

  def deliver
    TranslationProxy::Notification.deliver(self)
  end

  def translated_xliff
    xliffs.where(translated: true).last
  end

  # https://git.onthegosystems.com/icanlocalize/icanlocalize/commit/9441e4e73a3a5b2e5868ea6e7c12673987c006d3
  # Send request to TAS to generate the output xliff
  def ask_tas_to_generate_xliff_from_translated_version
    version = revision.versions.last
    send_output_notification(version, version.user)
  end

  def base_xliff
    xliffs.to_a.select { |x| !x.translated }.last
  end
  alias untranslated_xliff base_xliff

  def migrate_to_xliff
    TasComm.new.migrate_to_xliff(self, cms_target_language.language, revision.versions.last)
  end

  def update_language_status(language_id, status)
    cms_target_language = cms_target_languages.where('language_id=?', language_id).first
    if cms_target_language
      cms_target_language.update_attributes!(status: status)
    end
  end

  def indicate_language_output(language_id)
    cms_target_language = cms_target_languages.where(language_id: language_id).first
    cms_target_language.update_attributes!(delivered: 1) if cms_target_language
  end

  def previous_requests
    return [] if !list_type || !list_id || !website
    website.cms_requests.where('(updated_at > ?) AND (list_type IS NOT NULL) AND (list_type=?) AND (list_id<?) AND (delivered IS NULL)', Time.now - 3 * DAY_IN_SECONDS, list_type, list_id)
  end

  def following_requests
    return [] if !list_type || !list_id || !website

    website.cms_requests.where('(list_type IS NOT NULL) AND (list_type=?) AND (list_id>?) AND (delivered IS NULL)', list_type, list_id).order('list_id ASC')
  end

  def versions_to_output
    versions = []
    if revision
      revision.translators.each do |translator|
        f_version = revision.versions.where(by_user_id: translator.id).order('id DESC').first
        versions << f_version if f_version
      end
    end

    versions
  end

  def detailed_status
    ctl = cms_target_languages[0]
    res = if revision.nil?
            if status == CMS_REQUEST_FAILED
              "Failed to process: #{error_description}"
            else
              _('Setting up project')
            end
          else
            if !paid?
              'Awaiting payment'
            else
              ctl ? _(CmsTargetLanguage::STATUS_TEXT[ctl.status]) : _('No target languages')
            end
          end

    if pending_tas == 1
      res = ActionController::Base.helpers.image_tag('icons/flag.png', alt: 'issues', title: 'Failed to process correctly', style: 'float: right') + ' ' + res
    end

    res
  end

  def awaiting_payment?
    revision.present? && !paid?
  end

  def released_and_not_started?
    translation_has_started = cms_target_language&.status != CMS_TARGET_LANGUAGE_CREATED
    done_processing_by_tas = pending_tas == 0 || updated_at < (Time.now - TAS_PROCESSING_TIME)
    (status == CMS_REQUEST_RELEASED_TO_TRANSLATORS && !translation_has_started && done_processing_by_tas)
  end

  def started?
    translation_has_started = cms_target_language&.status != CMS_TARGET_LANGUAGE_CREATED
    (status == CMS_REQUEST_RELEASED_TO_TRANSLATORS && translation_has_started)
  end

  def can_cancel?
    # Todo 01132016 - jon: Investigate why old records has updated_at and created_at as nil for these fields is auto populated
    cancellable_statuses = [CMS_REQUEST_CREATING,
                            CMS_REQUEST_WAITING_FOR_PROJECT_CREATION,
                            CMS_REQUEST_PROJECT_CREATION_REQUESTED,
                            CMS_REQUEST_CREATING_PROJECT,
                            CMS_REQUEST_MARKED_FOR_CANCEL,
                            CMS_REQUEST_FAILED]

    cancellable_statuses.include?(status) || released_and_not_started?
  end

  def cancel_translation(force_cancel = false)
    return { success: false, error: 'status does not permit to cancel' } unless can_cancel? || force_cancel
    error_msg = nil

    if Rails.env.production?
      # 99.29% of CmsRequests created between Jan 2017 and Jan 208 have a tp_id
      if tp_id
        TranslationProxy::Notification.cancel(self)
      elsif website.platform_kind == WEBSITE_WORDPRESS
        begin
          server = website.get_server
          server.call('ictl.cancelTranslationRequest', website.login, website.password, id)
        rescue
          error_msg = 'RPC for ictl.cancelTranslationRequest failed'
        end
      elsif (website.platform_kind == WEBSITE_DRUPAL) && (website.pickup_type == PICKUP_BY_RPC_POST)
        server = website.get_server
        # sha.new("%s%i%i" % (accesskey, website_id, cms_request_id)).hexdigest()
        if !cms_id.blank?
          signature = Digest::SHA1.hexdigest('%s%d%d%s' % [website.accesskey, website.id, id, cms_id])
          begin
            res = server.call('icanlocalize.cancel_translation_by_cms_id', signature, website.id, id, cms_id)
            logger.info "---------- icanlocalize.cancel_translation_by_cms_id(#{signature},#{website.id}, #{id}, #{cms_id}) => #{res}"
            unless (res == 1) || (res == 4)
              error_msg = 'RPC result for cancel request is %d' % res
            end
          rescue
            error_msg = 'RPC for icanlocalize.cancel_translation_by_cms_id failed'
          end
        else
          signature = Digest::SHA1.hexdigest('%s%d%d' % [website.accesskey, website.id, id])
          begin
            res = server.call('icanlocalize.cancel_translation', signature, website.id, id)
            logger.info "---------- icanlocalize.cancel_translation(#{signature},#{website.id}, #{id}) => #{res}"
            unless (res == 1) || (res == 4)
              error_msg = 'RPC result for cancel request is %d' % res
            end
          rescue
            error_msg = 'RPC for icanlocalize.cancel_translation failed'
          end
        end
      end
    end

    return { success: false, error: error_msg } if error_msg

    # The `before_destroy :cleanup_before_destroy` callback does some additional
    # cleaning up.
    destroyed_record = destroy
    { success: !!destroyed_record, error: nil }
  end

  def notify_translation_started
    if website.platform_kind == WEBSITE_WORDPRESS
      server = website.get_server
      if Rails.env != 'test'
        begin
          server.call('ictl.setTranslationStatus', website.login, website.password, id, 4, 'Translation in progress')
        rescue
          return false
        end
      end
    end

    true
  end

  def automatic_translator_assignment?
    self.website_translation_offer.try(:automatic_translator_assignment) == true
  end

  def calculate_required_balance(cms_target_languages = nil, translator = nil,
                                 contract: nil)

    required_balance, bid_amounts, rental_amounts, payments_to_translator =
      if automatic_translator_assignment?
        # Automatic translator assignment uses fixed prices (no bidding)
        total_price_for_automatic_translator_assignment
      elsif translator&.private_translator? || website_translation_offer&.all_translators_are_private?
        # Private translators are always free (all their translation jobs cost $0)
        ctl_id_and_zero = { cms_target_language.id => 0 }
        [0, ctl_id_and_zero, ctl_id_and_zero, ctl_id_and_zero]
      else # Manual translator assignment (with bidding)
        # Passing the translator as an argument here is important, as a language
        # pair may have more than one accepted translator with different bid
        # amounts and we need to know the correct bid to apply.
        total_price_for_manual_translator_assignment(
          cms_target_languages = cms_target_languages,
          translator = translator,
          contract: contract
        )
      end

    [required_balance, bid_amounts, rental_amounts, payments_to_translator]
  end

  def locate_contract(target_language, translator = nil)
    @contracts = {} unless @contracts

    return @contracts[[target_language, translator]] if @contracts.key?([target_language, translator])

    conditions = "(website_translation_offers.from_language_id=#{language_id}) AND (website_translation_offers.to_language_id=#{target_language.id}) AND (website_translation_contracts.status=#{TRANSLATION_CONTRACT_ACCEPTED})"
    conditions += " AND (website_translation_contracts.translator_id=#{translator.id})" if translator

    # If there are more than one accepted translators for a language pair and
    # their bid amounts are different, we will charge the highest bid amount
    # from the client (when this method is called before
    # CmsRequestsController#assign_to_me is called, it does not receive a
    # translator as an argument). If the translator that clicked the "Start
    # Translation" button (triggers CmsRequestsController#assign_to_me) is the
    # one with the lowest bid, then this method receives the translator as an
    # argument, finds the contract with the lowest bid and the remaining amount
    # (the difference between the highest bid and the bid of the translator
    # which is actually translating this cms_request) will remain in
    # the client's ICL account.
    website_translation_contract = website.website_translation_contracts.joins(:website_translation_offer).where(conditions).max_by(&:amount)

    @contracts[[target_language, translator]] = website_translation_contract

    website_translation_contract
  end

  def disp_dict(dict)
    (dict.collect { |k, v| "#{k}:#{v}" }).join(',')
  end

  # cms_target_language is not neccesary, only added to keep legacy compatibility
  def html_output(cms_target_language = nil)
    if tp_id
      output_object = translated_xliff
    else
      unless cms_target_language
        cms_target_language = cms_target_languages.first
      end
      output_object = cms_target_language.cms_downloads.first
    end

    raise NotTranslated.new('CMS Download / Xliff file not found') unless output_object

    output_object.to_html
  end

  # delete the translation and set the cms_request to be processed by tas (project creation)
  def reset!(destroy_comm_errors = true)
    # @ToDo add refund money if present on money account for bidding project
    revision.destroy if revision
    self.status = 1
    self.last_operation = 1
    self.pending_tas = 1
    cms_target_languages.each { |ctl| ctl.update_attribute :status, CMS_TARGET_LANGUAGE_CREATED }
    save!
    comm_errors.destroy_all if destroy_comm_errors
    self
  end

  # This method generated python code to be run in TAS, use it to debug xliff output
  # generation
  def generate_code_to_debug_tas_xliff_ouput
    puts "sys.GetApp().set_mode('production')\n" \
         "website_id = #{website.id}\n" \
         "cms_request_id = #{id}\n" \
         "session_id = '#{TasComm.new.create_session_for_user website.client}'\n" \
         "language_id = #{cms_target_language.language_id}\n" \
         "project_id = #{revision.project_id}\n" \
         "revision_id = #{revision.id}\n" \
         "version_id = #{revision.versions.last.id}\n" \
         "TAS_worker.generate_xliff(cms_request_id, session_id, website_id,\n" \
         '        language_id, project_id, revision_id, version_id)'
  end

  def cms_target_language
    cms_target_languages.take
  end

  def webta_format(user = nil, translation_type = nil)
    translation_type ||= 'translate'
    validations = {
      translate: self.cms_target_language&.translator == user,
      review: self.revision&.revision_languages&.take&.managed_work&.translator == user
    }
    raise ActionController::RoutingError, 'Not Found' unless validations[translation_type.to_sym] || Translation::SuperTranslator.user_exists?(user)
    self.webta_attributes.to_json
  end

  def build_mrk_pairs
    mrk_pairs = []
    source_mrks = loaded_source_mrks
    target_mrks = loaded_target_mrks
    target_mrks_map = target_mrks.index_by(&:id)

    source_mrks.select(&:translatable?).each do |source_mrk|
      target_mrk = target_mrks_map[source_mrk.target_id]

      mrk_pairs << {
        source_mrk: {
          id: source_mrk.id,
          mrk_status: source_mrk.mrk_status,
          mrk_id: source_mrk.mrk_id,
          content: source_mrk.content
        },
        target_mrk: {
          id: target_mrk.id,
          mrk_status: target_mrk.mrk_status,
          mrk_id: target_mrk.mrk_id,
          content: target_mrk.content
        }
      }
    end
    mrk_pairs
  end

  def auto_save_untranslatable_mrks
    untranslatable_mrks = loaded_mrks.select(&:untranslatable?).select do |x|
      x.mrk_status == XliffTransUnitMrk::MRK_STATUS[:original]
    end

    XliffTransUnitMrk.where(id: untranslatable_mrks.map(&:id)).update_all(
      mrk_status: XliffTransUnitMrk::MRK_STATUS[:translation_completed]
    )
  end

  def loaded_mrks
    @loaded_mrks ||= begin
      bx_id = base_xliff.id
      self.xliff_trans_unit_mrks.to_a.select { |x| x.xliff_id == bx_id }
    end
  end

  def loaded_source_mrks
    loaded_mrks.select { |x| x.mrk_type == XliffTransUnitMrk::MRK_TYPES[:source] }.sort_by(&:id)
  end

  def loaded_target_mrks
    loaded_mrks.select { |x| x.mrk_type == XliffTransUnitMrk::MRK_TYPES[:target] }.sort_by(&:id)
  end

  def save_webta_progress(xliff_id, mrk_params)
    mrk = XliffTransUnitMrk.find_by_id(mrk_params[:id])
    return ApiError.new(409, 'Not matching mrk with xliff').error if mrk.present? && mrk.xliff_trans_unit.parsed_xliff.xliff.id != xliff_id
    return ApiError.new(409, 'An updated translation was sent by client').error unless xliff_id == self.base_xliff.id
    return ApiError.new(404, 'Can not find text to save.').error unless mrk

    content = Base64.decode64(mrk_params[:translated_text]).to_s.gsub(/<br[^>]*data-mce-bogus[^>]+>/, '')
    # UTF-8 encoding is added to check non breaking space
    return ApiError.new(417, 'Missing translated text').error if content.force_encoding('UTF-8').blank?
    mrk.content = content
    return ApiError.new(417, 'The translation is missing formatting markers').error unless mrk.has_all_markers?
    mrk.update_status(mrk_params[:mstatus])
    mrk.save!
    return { code: 200, status: 'OK', message: 'Translation completed' }
  rescue => e
    return ApiError.new(500, "Not saved due to error: #{e.message}").error
  end

  def complete_webta(user)
    Logging.log(self, :complete_webta)
    bid = self.revision.chats.where(translator_id: self.translator.id).last.bids.where(won: true).first
    chkbid = self.revision.all_bids.where(won: true).first
    return ApiError.new(404, 'Can not complete this translation.').error unless bid && bid == chkbid
    return ApiError.new(417, 'In order to declare this job as complete, you need to translate all the sentences in it. Some sentences are still not translated.').error unless self.base_xliff.parsed_xliff.all_mrk_completed?

    open_issues = self.mrk_issues.open_issues.select { |x| x.target.is_a? Translator }
    # return error when translator tries to complete translation with open issues
    return ApiError.new(417, 'The sentence has open issues. Please respond to them before saving the translation.').error if open_issues.present? && user.id != bid.managed_work.translator_id
    self.enqueue_redelivery if [CMS_REQUEST_TRANSLATED, CMS_REQUEST_DONE].include? self.status
    status_message = bid.webta_declare_done(user.id, self)
    update_attributes(webta_completed: true)
    return { code: 200, status: 'OK', message: status_message }
  rescue MoneyTransactionProcessor::NotEnoughFunds => e
    Rails.logger.error("Error when trying to complete translation via WEBTA with NotEnoughFunds. #{e.inspect}.\n" \
                         "Stack that caused the exception:\n#{Logging.format_callstack(self, caller)}")
    return ApiError.new(402, 'This translation cannot be declared as complete right now, please contact support.').error
  rescue => e
    Rails.logger.error("Error when trying to complete translation via WEBTA. #{e.inspect}")
    return ApiError.new(500, "Can't complete this translation.").error
  end

  def add_translated_xliff
    filename = "output_#{self.base_xliff.id}_#{self.base_xliff.filename}.gz"
    tr_x = Xliff.new
    tr_x.cms_request = self
    tr_x.translated = true
    content = original_xliff_content
    tr_x.uploaded_data = TempContent.new(filename, 'application/gzip', content)
    tr_x.save!
  end

  def redeliver
    add_translated_xliff
    deliver
  end

  def enqueue_redelivery
    self.delay(queue: 'redeliver_xliff', priority: 5).redeliver
  rescue => e
    Rails.logger.error("Error when trying to redeliver translation via WEBTA #{e.inspect}")
    return ApiError.new(500, "Can't redeliver this translation").error
  end

  def original_content
    base_xliff.get_contents.delete("\r")
  end

  def parsed_content
    base_xliff.parsed_xliff.full_xliff
  end

  def translated_content
    xliffs.select(&:translated?).last.get_contents.delete("\r")
  end

  def repair!
    ActiveRecord::Base.transaction do
      bx = self.base_xliff
      bx.parsed_xliff.destroy
      bx.create_new_parsed_xliff
    end
  end

  def original_xliff_content
    Otgs::Segmenter.restore_original_xml(self.base_xliff.parsed_xliff.full_xliff)
  end

  def update_tm
    TranslationMemoryActions::UpsertTranslatedMemory.new.call(cms_request: self)
  end

  def webta_attributes(short_version = false)
    cms = {
      id: self.id,
      title: self.title,
      permlink: self.permlink,
      cms_id: self.cms_id,
      word_count: self.word_count,
      deadline: (self.deadline || self.created_at + 5.days).to_i,
      started: self.base_xliff.parsed_xliff.created_at.to_i,
      source_language: self.language,
      target_language: self.cms_target_languages.first.language,
      website: {
        id: self.website.id,
        name: self.website.name,
        description: self.website.description,
        url: self.website.url
      },
      project: {
        id: self.revision.project.id,
        name: self.revision.project.name
      },
      revision: {
        id: self.revision.id,
        description: self.revision.description,
        name: self.revision.name
      },
      status: self.status,
      tmt_enabled: self.get_current_translators_tmt_config.try(:enabled) || false
    }

    # Todo investigate why we have 2 managed_work
    # managed_work = self.revision.revision_languages.where(language_id: self.cms_target_language.language_id).last.managed_work
    managed_work = self.website.website_translation_offers.where(to_language_id: self.cms_target_language.language_id).last.managed_work
    cms[:review_type] = managed_work.get_webta_review_status

    if short_version
      cms[:progress_details] = {
        total_words: self.base_xliff.parsed_xliff.word_count,
        translated_words: self.translated_words
      }
      cms[:status] = self.status
    else
      cms[:base_xliff] = {
        id: self.base_xliff.id,
        content_type: self.base_xliff.content_type,
        filename: self.base_xliff.filename,
        translated: self.base_xliff.translated
      }
      cms[:issues] = self.mrk_issues.map { |issue| issue.to_json(true) } if self.mrk_issues.present?
      cms[:content] = build_mrk_pairs
    end
    cms
  end

  def translated_words
    mrks = base_xliff.xliff_trans_unit_mrks.select do |x|
      x.mrk_type == XliffTransUnitMrk::MRK_TYPES[:source] &&
        x.mrk_status > XliffTransUnitMrk::MRK_STATUS[:in_progress]
    end

    mrks.map(&:tm_word_count).reduce(0, &:+)
  end

  def managed_work
    self.try(:revision).try(:revision_languages).last.try(:managed_work)
  end

  def reviewer
    managed_work.try(:translator)
  end

  def create_mrk_issue(params, current_user)
    mrk_id = params[:mrk][:id]
    xliff_trans_unit_mrk = XliffTransUnitMrk.find_by_id(mrk_id)
    mrk_type = params[:mrk][:mrk_type]
    if mrk_type.present? && mrk_type.to_i == XliffTransUnitMrk::MRK_TYPES[:source]
      xliff_trans_unit_mrk &&= xliff_trans_unit_mrk.source_mrk
      return ApiError.new(404, "Source XliffTransUnitMrk with id: #{mrk_id} not found", 'NOT FOUND').error unless xliff_trans_unit_mrk
    end
    return ApiError.new(404, "XliffTransUnitMrk with ID: #{mrk_id} was not found", 'NOT FOUND').error unless xliff_trans_unit_mrk

    xliff_id = params[:xliff_id]
    return ApiError.new(409, 'Not matching mrk with xliff').error if xliff_trans_unit_mrk.xliff.id != xliff_id

    message_body = params[:issue][:message_body]
    return ApiError.new(400, 'Message body is required, but it was empty', 'INVALID DATA').error if message_body.empty?

    issue = Issue.new
    issue.owner = xliff_trans_unit_mrk
    issue.initiator = current_user
    issue_kind = params[:issue][:kind]
    if issue_kind.present?
      begin
        issue_kind = issue_kind.constantize
      rescue NameError => e
        return ApiError.new(400, 'Issue kind is invalid', 'INVALID DATA').error
      end
    else
      issue_kind = ISSUE_GENERAL_QUESTION
    end
    issue.kind = issue_kind
    issue.title = (self.title || '').truncate(200, omission: '') + " issue ##{self.mrk_issues.count + 1}"
    issue.target = current_user == self.cms_target_language.translator ? self.website.client : self.cms_target_language.translator
    issue.status = ISSUE_OPEN
    issue.message = message_body
    issue.save!

    message = Message.new(body: issue.message, chgtime: Time.now)
    message.user = issue.initiator
    message.owner = issue
    message.save!

    if params[:involve_supporter].present? && current_user == self.revision.revision_languages&.first&.managed_work&.translator
      support_ticket = SupportTicket.new
      support_ticket.subject = "Review escalation for WebTA CMS Job ID: #{self.id}"
      support_ticket.message = issue.message
      support_ticket.create_time = Time.now
      support_ticket.status = SUPPORT_TICKET_CREATED
      support_ticket.normal_user = current_user
      support_ticket.support_department_id = 1
      if support_ticket.save!
        Message.create!(
          body: support_ticket.message,
          chgtime: Time.now,
          owner: support_ticket,
          user: current_user
        )
      end
    end

    issue.to_json
  rescue => e
    return ApiError.new(400, e.message, 'UNEXPECTED ERROR').error
  end

  def find_mrks_count_by_cms_id
    cms_request = self
    return ApiError.new(404, "CmsRequest with ID: #{cms_request_id} was not found", 'NOT FOUND').error unless cms_request

    mrks = cms_request.xliff_trans_unit_mrks.includes(:issues)
    issue_json = {}
    mrks.each do |mrk|
      all_issues = mrk.issues.to_a
      issues = all_issues.select { |x| x.status == ISSUE_OPEN }

      num_client_issues = issues.count { |x| x.target_id == cms_request.website.client.id }
      num_translator_issues = issues.count { |x| x.target_id == cms_request.cms_target_language.translator.id }

      if num_client_issues > 0 || num_translator_issues > 0
        issue_json[mrk.id] = { for_client: num_client_issues, for_translator: num_translator_issues }
      end
    end
    issue_json
  rescue => e
    return ApiError.new(400, e.message, 'UNEXPECTED ERROR').error
  end

  def create_message_by_webta(params, user)
    issue = Issue.find_by_id(params[:id])
    return ApiError.new(404, "Issue with ID: #{params[:id]} was not found", 'NOT FOUND').error unless issue
    return ApiError.new(400, 'Message body is not present', 'NO MESSAGE BODY').error if params[:message].blank? || params[:message][:body].blank?
    message = Message.new(body: params[:message][:body], chgtime: Time.now, user: user, owner: issue)
    message.save!
    message.to_json
  rescue => e
    return ApiError.new(400, e.message, 'UNEXPECTED ERROR').error
  end

  def close_issue_by_webta(id, closer)
    issue = Issue.find_by_id(id)
    return ApiError.new(404, "Issue with ID: #{id} was not found", 'NOT FOUND').error unless issue

    unless issue.initiator_id == closer.id
      return ApiError.new(400, 'Issue does not have reply messages', 'NO REPLY').error if issue.messages.count < 2
    end
    issue.update_attributes(status: ISSUE_CLOSED)
    issue.to_json
  rescue => e
    return ApiError.new(400, e.message, 'UNEXPECTED ERROR').error
  end

  def preview
    Nokogiri::XML(self.base_xliff.parsed_xliff.recreate_original_xliff).css('target').map(&:text).join('<br />').gsub(/(\[.*?\])/, '')
  end

  # This method is to be used until when TM migration is done, then should be deleted
  def self.check_x
    stats = []
    CmsRequest.find_each do |c|
      stats << { id: c.id, xliffs: c.xliffs.size, versions: c.try(:revision).try(:versions).try(:size) }
    end
    f = File.open('cms_stats.txt', 'wb')
    parsed_stats = {
      two_two: 0,
      equal_not_zero: 0,
      no_xliff: 0,
      less_xliffs: 0,
      less_versions: 0,
      equal_zero: 0,
      total: stats.size
    }
    stats.each do |s|
      s[:xliffs] = 0 if s[:xliffs].nil?
      s[:versions] = 0 if s[:versions].nil?
      f.puts("#{s[:id]},#{s[:xliffs]},#{s[:versions]}")
      parsed_stats[:two_two] += 1 if s[:xliffs] == 2 && s[:versions] == 2
      parsed_stats[:equal_not_zero] += 1 if s[:xliffs] != 0 && s[:versions] == s[:xliffs]
      parsed_stats[:no_xliff] += 1 if s[:xliffs] == 0
      parsed_stats[:less_xliffs] += 1 if s[:xliffs] != 0 && s[:versions] > s[:xliffs]
      parsed_stats[:less_versions] += 1 if s[:versions] != 0 && s[:versions] < s[:xliffs]
      parsed_stats[:less_versions] += 1 if s[:versions] == 0 && s[:xliffs] == 0
    end
  end

  def paid?
    has_reserved_money = pending_money_transaction.present?
    translation_started = cms_target_language&.status &.> CMS_TARGET_LANGUAGE_CREATED
    translation_started || has_reserved_money
  end

  # The review enabled/disabled status selected by the client for the language
  # pair in the "Website page" is stored in website_translation_offer.managed_work.active
  # and  should be used as the default for newly created cms_requests.
  #
  # When the CmsRequest is created, it does not yet have an associated
  # CmsTargetLanguage, so there is no way to know which is the target language,
  # unless we pass it as an argument.
  def set_default_review_status(target_language = nil)
    default_review_status = website_translation_offer(target_language)&.review_enabled_by_default?
    update(review_enabled: default_review_status) if self.review_enabled.nil?
  end

  # We canNOT just calculate the price per word per language pair because a language
  # pair may have some CmsRequests with review enabled and other with review
  # disabled. So we have to calculate the price per word per CmsRequest. The
  # only scenario where it's ok to calculate per language pair, is at the
  # payment (Pending Translation Jobs page) because review can only be enabled
  # or disabled for all **pending** CmsRequests at that time. But when the
  # CmsRequests are no longer pending (after payment), we can have a mix of
  # review enabled and disabled in the same language pair.
  def price_per_word_for_automatic_translator_assignment
    price_per_word_without_review = self.website_translation_offer.language_pair_fixed_price.actual_price
    review_price_per_word = self.review_enabled ? (price_per_word_without_review * REVIEW_PRICE_PERCENTAGE) : 0
    price_per_word_without_review + review_price_per_word
  end

  # Exceptions
  class NotTranslated < StandardError; end

  class NotFound < JSONError
    def initialize(id)
      @code = CMS_REQUEST_NOT_FOUND
      @message = "Can't find job with ID #{id}"
    end
  end

  def completed?
    self.status == CMS_REQUEST_DONE
  end

  def translated?
    self.status == CMS_REQUEST_TRANSLATED
  end

  def in_progress?
    started? || translated?
  end

  def complete!
    update_attributes(status: CMS_REQUEST_DONE, completed_at: Time.now)
    unblock_if_need!
  end

  def unblock_if_need!
    blocked_id = blocked_cms_request_id

    if blocked_id.present?
      Rails.logger.info("[#{self.class.name}##{__callee__}] unblock_cms #{blocked_id}")
      update_attributes(blocked_cms_request_id: nil)
      blocked_cms = CmsRequest.find_by(id: blocked_id)
      blocked_cms&.base_xliff&.create_parsed_xliff
      CmsActions::Process.new(blocked_id).delay.call
    end
  end

  def block_cms!(cms_id)
    update_attributes(blocked_cms_request_id: cms_id)
    block_review!
  end

  def blocked_cms
    blocked_cms_request_id ? self.class.find_by(id: blocked_cms_request_id) : nil
  end

  def block_review!
    Rails.logger.info("[#{self.class}][block_review]")

    unless review_enabled || (review_enabled.nil? && revision.revision_language.managed_work&.enabled?)
      Rails.logger.info("[#{self.class}][review_disabled_already]")
      return
    end

    update_attributes!(review_enabled: false)
    revision.revision_language.managed_work.update_attributes!(active: false)
    review_amount = revision.reviewer_payment(revision.revision_language.selected_bid)
    Rails.logger.info("[#{self.class}][review_disabled][amount=#{review_amount}]")

    # Refund review amount
    if (cms_target_language.status == CMS_TARGET_LANGUAGE_CREATED) && self.pending_money_transaction.present?
      # Translation was not yet started, review amount is still on hold_sum
      website.client.money_account.release_hold_sum(review_amount)
      Rails.logger.info("[#{self.class}][release_hold_sum][amount=#{review_amount}]")
    elsif cms_target_language.status != CMS_TARGET_LANGUAGE_CREATED
      # Translation is in progress, review amount is in an escrow account
      escrow_account = revision.revision_language.selected_bid.account
      client_account = website.client.money_account
      MoneyTransactionProcessor.transfer_money(escrow_account, client_account, review_amount,
                                               DEFAULT_CURRENCY_ID, TRANSFER_REFUND_FROM_BID_ESCROW)
      Rails.logger.info("[#{self.class}][refund_money_from_escrow][amount=#{review_amount}]")
    end
  end

  def deadline_elapsed_percentage
    return 0 if self.deadline.blank?
    now = Time.zone.now
    diff = self.deadline - self.created_at
    (((now - self.created_at) / diff.abs) * 100)
  end

  def toggle_tmt_config
    return false unless ENABLE_MACHINE_TRANSLATION
    config = get_current_translators_tmt_config
    config.toggle_mt_config
    config.enabled
  end

  def get_current_translators_tmt_config
    config = tmt_configs.where(translator: cms_target_language.translator).first
    config = tmt_configs.create(translator: cms_target_language.translator, enabled: false) if config.nil?
    config
  end

  def block_in_ta_tool?
    return false unless self.translator&.ta_blocked?
    !self.ta_tool_parent_completed? || self.webta_parent_completed?
  end

  def toggle_force_ta
    if force_ta?
      update_attributes(ta_tool_parent_completed: false, webta_parent_completed: false)
    else
      update_attributes(ta_tool_parent_completed: true, webta_parent_completed: false)
    end
    force_ta?
  end

  def force_ta?
    return true if ta_tool_parent_completed == true && webta_parent_completed == false
    return false if ta_tool_parent_completed == false && webta_parent_completed == false
  end

  private

  # After a cms_request is paid for, review can no longer be disabled.
  def review_enabled_validation
    # The only exception is when WPML sends a page for translation, then sends an
    # update for that same page before the first translation is completed. In
    # that case, the second CmsRequest is blocked until the first one is
    # completed, so CmsRequest#block_review! disables the review for the first
    # one, so it can be completed faster.
    # Check if this CmsRequest blocks any other CmsRequests.
    return if blocked_cms_request_id.present?

    if paid? && review_enabled_changed? && review_enabled == false
      errors.add(
        :review_enabled,
        'can\'t be disabled for this translation job because it has already ' \
        'been paid for.'
      )
    end
  end

  # The CmsRequest#review_enabled attribute was added when the WPML 3.9 flow
  # was created. There are many places in the older code that rely on other
  # ways to tell if review is enabled or disabled, hence we can't just use
  # the review_enabled attribute. This should be refactored.
  def charge_for_review?(primary_translator = nil)
    # TODO: Refactor what determines if review is enabled or disabled.
    #
    # In order or preference:
    #   1st option: "review_enabled" attribute of CmsRequest
    #   2nd option: cms_request.revision.revision_language.first.managed_work (per cms_request)
    #   3rd option: website_translation_offer.managed_work (per language pair)
    #
    #
    # We have to be able to enable/disable review per cms_request.
    # revision_language is only created when the primary translator (not the
    # reviewer) clicks the "Start Translating" button (after the client pays),
    # which calls CmsRequestsController#assign_to_me. That's why
    # revision_language.managed_work can't be used to calculate the cost of a
    # cms_request before its paid.

    # The new WPML client flow (for WPML 3.9+) uses a new CmsRequest attribute
    # called "enabled_review" to determine if review is enabled or disabled
    # for a cms_request. If this attribute is present (not nil), use it and
    # ignore all other ways to determine if review is enabled or disabled.
    return self.review_enabled unless self.review_enabled.nil?

    wto_managed_work_is_active = website_translation_offer.managed_work.try(:active?) || false
    # Notice that primary_translator is received as an argument, it does not refer
    # to the translator associated to this CmsRequest.
    # (website_helper#unfunded_requests) send primary_translator = nil, which means
    # if there is no reviewer assigned we would not charge for the review (that's
    # bad). That is why we "!primary_translator" as a condition in the following if
    # statement.
    no_translator_assigned = primary_translator.nil?
    # here managed_work can be nil in tests
    different_translator_for_review = website_translation_offer.managed_work.try(:translator) != primary_translator

    # Ensure that the same translator is not assigned for both the translation and
    # the review jobs (he can't review his own work).
    wto_managed_work_is_active && (no_translator_assigned || different_translator_for_review)
  end

  def total_price_for_manual_translator_assignment(cms_target_languages = nil,
                                                   primary_translator = nil,
                                                   contract: nil)
    # TODO: Remove this parameters
    # Be careful with primary_translator, it's sent as nil apparently to catch
    # contracts without translators.
    cms_target_languages ||= self.cms_target_languages
    required_balance = 0
    bid_amounts = {}
    rental_amounts = {}

    payments_to_translator = {}

    cms_target_languages.each do |cms_target_language|
      # Contract may be passed in as an argument to avoid the SQL queries
      # performed by #locate_contract
      contract ||= locate_contract(cms_target_language.language, primary_translator)

      next unless contract
      rental_amounts[cms_target_language.id] = 0
      bid_amounts[cms_target_language.id] = 0
      payments_to_translator[cms_target_language.id] = 0

      next unless cms_target_language.word_count && contract.amount
      cost = cms_target_language.word_count * contract.amount
      cost *= 1 + REVIEW_PRICE_PERCENTAGE if charge_for_review?(primary_translator)

      bid_amounts[cms_target_language.id] = BigDecimal(contract.amount.to_s)
      payments_to_translator[cms_target_language.id] = cost.ceil_money

      required_balance += cost
    end

    # logger.info "----------- ASSIGN_TO_ME: required_balance=#{required_balance},bid_amounts=#{disp_dict(bid_amounts)},rental_amounts=#{disp_dict(rental_amounts)},payments_to_translator=#{disp_dict(payments_to_translator)}"
    [required_balance.ceil_money, bid_amounts, rental_amounts, payments_to_translator]
  end

  def total_price_for_automatic_translator_assignment
    # Memoize the WebsiteTranslationOffer
    wto = website_translation_offer

    # fix for https://onthegosystems.myjetbrains.com/youtrack/issue/icldev-2491
    word_count = cms_target_language.word_count || 0
    total_price = word_count * price_per_word_for_automatic_translator_assignment # includes review cost

    # Must return an array with the following 4 items for backwards
    # compatibility with legacy code. The first item is a decimal and the
    # others are hashes.
    # TODO: refactor (see icldev-2509).
    # Do NOT include the review cost in bid_amounts
    bid_amounts = { cms_target_language.id => BigDecimal(wto.price_per_word_without_review.to_s) }
    rental_amounts = { cms_target_language.id => BigDecimal(0) }
    payments_to_translator = { cms_target_language.id => total_price.ceil_money }
    [total_price.ceil_money, bid_amounts, rental_amounts, payments_to_translator]
  end

  def cleanup_before_destroy
    Rails.logger.info("[#{self.class.name}##{__callee__}] destroying_cms_request #{id}")

    # If there is a PMT, release money from the hold_sum back to the client's
    # balance before deleting the CmsRequest.
    PendingMoneyTransaction.release_money_for_cms_request(self) \
      if pending_money_transaction.present?
  end
end
