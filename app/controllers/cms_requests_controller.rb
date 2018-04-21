require 'rexml/document'
require 'base64'

class CmsRequestsController < ApplicationController
  include ::AuthenticateProject
  include ::RootAccountCreate
  include ::VersionsMethods

  prepend_before_action :setup_user, except: [:create, :download]
  prepend_before_action :locate_request, except: [:index, :count_requests_to_pickup, :create, :download, :cms_id, :report, :update_cms_id, :multiple_retry, :cancel_multiple_translations]
  prepend_before_action :locate_website, except: [:create, :download]
  before_action :authorize_user, except: [:create, :download]

  before_action :verify_translator, only: [:assign_to_me]
  before_action :verify_client, except: [:assign_to_me, :show, :close_all_errors, :create, :download, :get_html_output, :toggle_tmt_config]

  before_action :locate_target_language_by_name, only: [:cms_download, :save_html_output, :get_html_output]

  # TODO: check if disabling this only for JSON/XML requests and keeping it for HTML requests would cause any problems
  # disable CSRF token check to be able to accept requests from WPML
  skip_before_action :verify_authenticity_token

  layout :determine_layout

  include NotifyTas
  attr_reader :cms_request

  def index
    # for XML, display all requests, for HTML use a pager
    if params[:format] == 'xml'
      filter = params[:filter]
      container = params[:container]
      @show_languages = !params[:show_languages].blank?
      @cms_requests = if filter == 'pending_TAS'
                        @website.cms_requests.where(['cms_requests.status IN (?)', CMS_REQUEST_WAITING_FOR_TAS]).order('cms_requests.id ASC')
                      elsif filter == 'sent'
                        @website.cms_requests.where(['cms_requests.status = ?', CMS_REQUEST_RELEASED_TO_TRANSLATORS]).order('cms_requests.id ASC')
                      elsif filter == 'pickup'
                        if params[:limit]
                          @website.cms_requests.where(['(cms_requests.status = ?) AND EXISTS(SELECT * FROM cms_target_languages WHERE ((cms_target_languages.cms_request_id=cms_requests.id) AND (cms_target_languages.status=?)))', CMS_REQUEST_TRANSLATED, CMS_TARGET_LANGUAGE_TRANSLATED]).order('cms_requests.id ASC').limit(params[:limit])
                        else
                          @website.cms_requests.where(['(cms_requests.status = ?) AND EXISTS(SELECT * FROM cms_target_languages WHERE ((cms_target_languages.cms_request_id=cms_requests.id) AND (cms_target_languages.status=?)))', CMS_REQUEST_TRANSLATED, CMS_TARGET_LANGUAGE_TRANSLATED]).order('cms_requests.id ASC')
                        end
                      elsif !container.blank?
                        @website.cms_requests.where(container: container).order('cms_requests.id ASC')
                      else
                        if @show_languages
                          @website.cms_requests.includes(:cms_target_languages).order('cms_requests.id ASC')
                        else
                          @website.cms_requests.order('cms_requests.id ASC')
                        end
                      end
    else
      website_cms_requests = @website.cms_requests.left_outer_joins(:cms_target_languages, revision: [revision_languages: [:managed_work]])
      @header = _('Translation jobs in this project')

      if params[:set_args].to_i == 1
        @current_id = params[:id].blank? ? nil : params[:id]
        @current_title = params[:title].blank? ? nil : params[:title]
        @current_status = params[:status].blank? || (params[:status].to_i == -1) ? nil : params[:status].to_i
        @current_language = params[:to_language_id].blank? || (params[:to_language_id].to_i == -1) ? nil : params[:to_language_id].to_i
        @current_processing = params[:processing].blank? || (params[:processing].to_i == -1) ? nil : params[:processing].to_i
        @current_review_status = params[:review_status].blank? || (params[:review_status].to_i == -1) ? nil : params[:review_status].to_i
      elsif params[:clear_args].to_i != 1
        @current_id = session[:current_id]
        @current_title = session[:current_title]
        @current_status = session[:current_status]
        @current_language = session[:current_language]
        @current_processing = session[:current_processing]
        @current_review_status = session[:current_review_status]
      end

      session[:current_id] = @current_id
      session[:current_title] = @current_title
      session[:current_status] = @current_status
      session[:current_language] = @current_language
      session[:current_processing] = @current_processing
      session[:current_review_status] = @current_review_status

      cond_list = []
      cond_args = []
      if @current_id
        cond_list << '(cms_requests.id = ?)'
        cond_args << @current_id
      end
      if @current_title
        cond_list << '(cms_requests.title LIKE ?)'
        cond_args << '%' + @current_title + '%'
      end
      if @current_status
        cond_list << '(cms_target_languages.status = ?)'
        cond_args << (@current_status == CMS_TARGET_LANGUAGE_AWAITING_PAYMENT ? CMS_TARGET_LANGUAGE_CREATED : @current_status)
      end
      if @current_language
        cond_list << '(cms_target_languages.language_id = ?)'
        cond_args << @current_language
      end
      if @current_processing
        cond_list << '(cms_requests.pending_tas = ?)'
        cond_args << @current_processing
      end

      if @current_review_status
        cond_list << (@current_review_status == -2 ? '(cms_requests.review_enabled != ?)' : '(managed_works.translation_status = ? AND cms_requests.review_enabled IS TRUE)')
        cond_args << (@current_review_status == -2 ? 1 : @current_review_status)
      end

      conds = cond_list.any? ? [cond_list.join(' AND ')] + cond_args : nil

      @total_count = website_cms_requests.where(conds).count
      @cms_requests = website_cms_requests.
                      where(conds).
                      order('cms_requests.id DESC')
      if params[:status].to_i == CMS_TARGET_LANGUAGE_AWAITING_PAYMENT
        @cms_requests = @cms_requests.select(&:awaiting_payment?)
      end
      @cms_requests = Kaminari.paginate_array(@cms_requests).page(params[:page]).per(PER_PAGE)

      if @user.has_supporter_privileges?
        @pending_cms_requests = website_cms_requests.find_all { |x| x.pending_tas == 1 }
      end

      @list_of_pages = (1..@cms_requests.total_pages).to_a
      @filter_status = [['-- ' + _('Any') + ' --', -1]] + CmsTargetLanguage::STATUS_TEXT.collect { |k, v| [_(v), k] }
      @filter_languages = [['-- ' + _('Any') + ' --', -1]] + @website.website_translation_offers.collect { |offer| [offer.to_language.nname, offer.to_language.id] }
      @filter_processing = [['-- ' + _('Any') + ' --', -1], [_('Normal'), 0], [_('Error'), 1]]
      @filter_review_status = [['-- ' + _('Any') + ' --', -1], [_('Will start after translation is finished'), MANAGED_WORK_CREATED], [_('Waiting for reviewer'), MANAGED_WORK_WAITING_FOR_REVIEWER], [_('Review completed'), MANAGED_WORK_COMPLETE], [_('Review in progress'), MANAGED_WORK_REVIEWING], [_('Review disabled'), -2]]
      @filter_languages.uniq!

    end
    respond_to do |format|
      format.html
      format.xml
    end
  end

  def count_requests_to_pickup
    if params[:format] == 'xml'
      @count = @website.cms_requests.where(['(cms_requests.status = ?) AND EXISTS(
        SELECT * FROM cms_target_languages WHERE ((cms_target_languages.cms_request_id=cms_requests.id)
        AND (cms_target_languages.status=?)))',
                                            CMS_REQUEST_TRANSLATED, CMS_TARGET_LANGUAGE_TRANSLATED]).count
    end
    respond_to do |format|
      format.xml
    end
  end

  def report
    @header = _('Translation Progress Report')
    @processing_cnt = 0
    @completed = {}
    @languages_list = []
    @languages_map = {}
    @offers = {}

    # CMS_TARGET_LANGUAGE_CREATED - waiting for translator
    # CMS_TARGET_LANGUAGE_ASSIGNED - being translated
    # CMS_TARGET_LANGUAGE_DONE - translation complete

    @website.cms_target_languages.includes(:cms_request).each do |cms_target_language|
      if cms_target_language.cms_request.status <= CMS_REQUEST_CREATING_PROJECT
        @processing_cnt += 1
      else
        unless cms_target_language.word_count.nil?
          c = cms_target_language.cms_request
          lang_pair = [c.language, cms_target_language.language]
          unless @completed.key?(lang_pair)
            @completed[lang_pair] = { STATISTICS_WORDS => { CMS_TARGET_LANGUAGE_CREATED => 0, CMS_TARGET_LANGUAGE_ASSIGNED => 0, CMS_TARGET_LANGUAGE_DONE => 0 },
                                      STATISTICS_DOCUMENTS => { CMS_TARGET_LANGUAGE_CREATED => 0, CMS_TARGET_LANGUAGE_ASSIGNED => 0, CMS_TARGET_LANGUAGE_DONE => 0 } }
          end

          language_names = '%s %s' % [c.language.nname, cms_target_language.language.nname]
          unless @languages_map.key?(language_names)
            @languages_map[language_names] = lang_pair
            website_translation_offer = @website.website_translation_offers.where(['(from_language_id=?) AND (to_language_id=?)', c.language.id, cms_target_language.language.id]).first
            @offers[language_names] = website_translation_offer
            @languages_list << language_names
          end

          if [CMS_REQUEST_TRANSLATED, CMS_REQUEST_DONE].include?(c.status)
            @completed[lang_pair][STATISTICS_DOCUMENTS][CMS_TARGET_LANGUAGE_DONE] += 1
            @completed[lang_pair][STATISTICS_WORDS][CMS_TARGET_LANGUAGE_DONE] += cms_target_language.word_count
          elsif cms_target_language.status == CMS_TARGET_LANGUAGE_ASSIGNED
            @completed[lang_pair][STATISTICS_DOCUMENTS][CMS_TARGET_LANGUAGE_ASSIGNED] += 1
            @completed[lang_pair][STATISTICS_WORDS][CMS_TARGET_LANGUAGE_ASSIGNED] += cms_target_language.word_count
          else
            @completed[lang_pair][STATISTICS_DOCUMENTS][CMS_TARGET_LANGUAGE_CREATED] += 1
            @completed[lang_pair][STATISTICS_WORDS][CMS_TARGET_LANGUAGE_CREATED] += cms_target_language.word_count
          end
        end
      end
    end

    @languages_list.sort
  end

  # When creating a new cms_request, TAS makes a request to this action to find
  # previous cms_requests corresponding to the same WordPress page. If there are
  # any, it fetches the translated xta file from the previous jobs to apply TM
  # to the new job.
  def cms_id
    cms_id = params[:cms_id]
    previous_cms_requests = @website.cms_requests.where(
      cms_id: cms_id,
      pending_tas: false
    ).order('cms_requests.id ASC')

    webta_cms_requests = previous_cms_requests.select { |cms| cms.webta_completed || cms.webta_parent_completed }
    tas_cms_requests = previous_cms_requests - webta_cms_requests

    # TAS will look for translated xta files for all cms_requests whose IDs are
    # returned by this action to apply TM to the job that is being created.
    # If the previous jobs for the same WP page were translated with WebTA,
    # they will not have translated xta files (only a translated xliff), then
    # TAS will throw an error and trash the new job. By responding only with
    # the cms_requests that were translated with TA (which have an xta file),
    # we prevent that issue.
    logger.info("[#{self.class.name}##{__callee__}] skipping_tas_processing_for_webta_requests #{webta_cms_requests.map(&:id).join(', ')}") if webta_cms_requests.any?
    logger.info("[#{self.class.name}##{__callee__}] responding_with_ta_cms_requests #{tas_cms_requests.map(&:id).join(', ')}") if tas_cms_requests.any?

    @cms_requests = tas_cms_requests

    respond_to do |format|
      format.html
      format.xml
    end
  end

  def download
    head :not_acceptable unless request.format == Mime[:json]
    website = authenticate_project
    cms_request = website.cms_requests.find_by(id: params[:job][:id])
    raise CmsRequest::NotFound, params[:job][:id] unless cms_request
    xliff = cms_request.xliffs.reverse.find(&:translated?)
    raise Xliff::NotTranslated unless xliff

    send_file(xliff.full_filename, type: 'application/octet-stream')
  end

  def create
    # If is legacy WPML version handle and return
    unless params[:api_version]
      create_from_wpml_legacy
      return
    end

    head :not_acceptable unless request.format == Mime[:json]

    @cms_request = Create.new(self, authenticate_project).call

    Rails.logger.info("[#{self.class}][create][id=#{@cms_request.id}]")
    respond_to { |format| format.json }
  end

  def multiple_retry
    requests = CmsRequest.find(params[:cms_requests_ids])
    failed_ids = requests.map { |req| retry_cms_request(req, logger) ? nil : req.id }
    failed_ids.delete(nil)
    flash[:notice] = if failed_ids.any?
                       "The following requests failed to be retried: #{failed_ids.join(' ')}"
                     else
                       'Retried jobs successfully'
                     end

    redirect_to request.referer
  end

  def retry
    if @cms_request.can_cancel?
      @cms_request.reset!
      @message = @cms_request.retry_tas
    else
      set_err('Not allowed!')
      return
    end
    respond_to do |format|
      format.html do
        flash[:notice] = @message if @message
        redirect_to request.referer
      end
      format.xml
    end
  end

  # TAS is done processing, translation job will be made available for the
  # translator(s).
  def release
    # set the word count per target language
    @cms_request.cms_target_languages.each do |cms_target_language|
      wc = @cms_request.revision.lang_word_count(cms_target_language.language)

      if !wc || wc == 0
        @cms_request.revision.destroy if @cms_request.revision
        @cms_request.update_attributes!(pending_tas: 1)

        comm_error = CommError.new(cms_request: @cms_request,
                                   error_description: "GENERATED FROM ICL, INVALID WORD COUNT OF #{wc}")

        set_err('ERROR: Wordcount 0, not able to release.') && return
      end

      cms_target_language.word_count = wc
      cms_target_language.money_account = @cms_request.website.client.find_or_create_account(DEFAULT_CURRENCY_ID)
      cms_target_language.save!
    end

    # final revision updates
    revision = @cms_request.revision
    revision.update_attributes!(description: "Created by CMS update. This project is part of:\n#{revision.project.name}", project_completion_duration: 3, notified: 1)

    # release the project to translators
    if @cms_request.update_attributes(status: CMS_REQUEST_RELEASED_TO_TRANSLATORS)
      @result = { 'message' => 'Released' }
    else
      set_err('Cannot release')
      return
    end
    respond_to do |format|
      format.html
      format.xml
    end
  end

  def show
    @header = _('Details for recurring work in "%s"') % @website.name
    if @user[:type] == 'Translator'
      @cms_chats_to_complete = @user.pending_cms_chats
      accepted_lang_ids = @user.accepted_offers.where(from_language_id: @cms_request.language_id, website_id: @website.id).collect(&:to_language_id)
      if @cms_request.revision && (@cms_request.status >= CMS_REQUEST_RELEASED_TO_TRANSLATORS)
        possible_cms_target_languages = @cms_request.cms_target_languages.where(['(status = ?) AND (language_id IN (?))', CMS_TARGET_LANGUAGE_CREATED, accepted_lang_ids])
        @your_translations = @cms_request.cms_target_languages.where(translator_id: @user.id)

        @open_cms_target_languages = []
        # When a cms_request has an associated PendingMoneyTransaction record, it
        # means it's already paid for and the amount is on the client's hold_sum
        # (it was not yet moved to an escrow account). As of the implementation
        # of ICL v2, translators should only be allowed to work on CmsRequests
        # that have an associated PendingMoneyTransaction. Even if the client
        # has enough money in his ICL account, he must go to the new payment
        # page and click "Pay with my ICanLocalize account balance"
        is_cms_request_paid = PendingMoneyTransaction.where(owner: @cms_request).present?
        if is_cms_request_paid
          @open_cms_target_languages << @cms_request.cms_target_language
        else
          @missing_funding = true
        end
      else
        @your_translations = []
        @open_cms_target_languages = []
      end
    elsif @user.has_client_privileges?
      if @cms_request.revision
        @revision_id = @cms_request.revision.id
        @project_id = @cms_request.revision.project.id
      else
        @revision_id = nil
        @project_id = nil
      end
      @can_retry = (@cms_request.pending_tas == 1) || [CMS_REQUEST_WAITING_FOR_PROJECT_CREATION, CMS_REQUEST_PROJECT_CREATION_REQUESTED, CMS_REQUEST_CREATING_PROJECT].include?(@cms_request.status)
    end
    respond_to do |format|
      format.html
      format.xml
    end
  end

  def assign_to_me
    begin
      cms_target_language_ids = make_dict(params[:cms_target_language])
    rescue
      cms_target_language_ids = []
    end

    if !(%w(development test sandbox).include?(Rails.env) && !params[:assign_multiple].blank?) && (@user.pending_cms_chats.length >= MAX_ALLOWED_CMS_PROJECTS)
      logger.info '-------- ASSIGN_TO_ME_PROBLEM: You must first complete existing translations for this project'
      flash[:notice] = 'You must first complete existing translations for this project'
      redirect_to action: :show
      return
    end

    if cms_target_language_ids.empty?
      logger.info '-------- ASSIGN_TO_ME_PROBLEM: You must select which languages to begin translating to'
      flash[:notice] = 'You must select which languages to begin translating to'
      redirect_to action: :show
      return
    end

    target_languages_for_other_translators = @cms_request.cms_target_languages.where(['(id IN (?)) AND (status=?) AND ((translator_id IS NOT NULL) AND (translator_id != ?))', cms_target_language_ids, CMS_TARGET_LANGUAGE_CREATED, @user.id])
    unless target_languages_for_other_translators.empty?
      logger.info '-------- ASSIGN_TO_ME_PROBLEM: Selected language for other translator'
      flash[:notice] = 'The language you are trying to select was sent to another translator. Please open a support ticket and explain your steps to get into this screen.'
      redirect_to action: :show
      return
    end

    requested_cms_target_languages = @cms_request.cms_target_languages.where(['(id IN (?)) AND (status=?) AND ((translator_id IS NULL) OR (translator_id = ?))', cms_target_language_ids, CMS_TARGET_LANGUAGE_CREATED, @user.id])
    if requested_cms_target_languages.empty?
      logger.info '-------- ASSIGN_TO_ME_PROBLEM: All selected languages have already been assigned to another translator'
      flash[:notice] = 'All selected languages have already been assigned to another translator'
      redirect_to action: :show
      return
    end

    unless @cms_request.revision
      logger.info '-------- ASSIGN_TO_ME_PROBLEM: Project not fully set up yet'
      set_err('Project not fully set up yet')
      redirect_to controller: :translator
    end

    revision = @cms_request.revision
    project = revision.project
    wto = @cms_request.website_translation_offer

    # merge TM data to the version
    version = revision.versions[0]

    # don't apply TM if the user doesn't want. Also skip this part when rails
    # is on development mode to avoid "Errno::ENOENT No such file or directory"
    if @website.tm_use_mode != TM_IGNORE_MATCHES && version && !Rails.env.development?
      vu = VersionUpdateFromTm.new(version, @website, logger)
      vu.read
      language_names = requested_cms_target_languages.collect { |ctl| ctl.language.name }
      vu.update_languages(language_names)

      Zlib::GzipWriter.open(version.full_filename) { |gz| vu.write(gz) }

      version.size = File.size(version.full_filename)
      version.save!

      # reload the object completely, so that we don't have anything cached
      version = ::Version.find(version.id)
      version.update_statistics(@user)

      requested_cms_target_languages.each(&:reload)
    end

    if @cms_request.pending_money_transaction.nil?
      logger.info '-------- ASSIGN_TO_ME_PROBLEM: this cms_request is not paid for.'
      flash[:notice] = 'This translation job is not paid for. The client must pay before you can start translating.'
      redirect_to controller: :translator
      return
    end

    # Even though we already have the CmsRequest cost in the "amount" attribute
    # of the PendingMoneyTransaction, we STILL NEED TO RECALCULATE HERE, see the
    # explanation in a comment at the if statement below.
    translation_job_cost, bid_amounts = @cms_request.calculate_required_balance(requested_cms_target_languages, @user)
    pmt = @cms_request.pending_money_transaction
    reserved_amount_for_translation_job = pmt.amount

    if translation_job_cost < reserved_amount_for_translation_job
      # The PendingMoneyTransaction amount can be different from the CmsRequest cost
      # in the following scenario: On manual translator assignment mode, when more
      # than one translator is accepted by the client, if their bids have different
      # amounts, the highest bid amount is charged at payment time. However, if
      # the translator with the smaller bid amount clicks "Start translating"
      # (which calls CmsRequestsController#assign_to_me), we pass the translator
      # (@user) as an argument to CmsRequest#alculate_required_balance and it
      # calculates the cost of the CmsRequest using the lesser bid amount. The
      # lesser amount is charged from the client and the difference will remain
      # in the client's ICL account.
      logger.info "Translator #{@user.id} took CmsRequest #{@cms_request.id}. " \
                  "The amount (#{reserved_amount_for_translation_job}) " \
                  'of the PendingMoneyTransaction is greater than the CmsRequest ' \
                  "cost (#{translation_job_cost}). The remaining amount will " \
                  'be returned to the client\'s account. This behavior is ' \
                  'expected when bids of different amounts are accepted in ' \
                  'the same language pair.'
    end

    if translation_job_cost <= reserved_amount_for_translation_job
      # Release reserved money from the client hold_sum to the client's account
      # balance.
      PendingMoneyTransaction.release_money_for_cms_request(@cms_request)
    else
      # There is only one valid use case that I can think of that causes the
      # PendingMoneyTransaction amount to be lesser then the cost of the
      # CmsRequest: **after** the client paid (and the PMT was created), a new
      # translator with a higher bid amount was accepted by the client for
      # the language pair and took this CmsRequest. Check if that's the case:
      wtcs_accepted_before_payment =
        wto.accepted_website_translation_contracts.
        where("website_translation_contracts.accepted_by_client_at < '#{pmt.created_at.to_s(:db)}'")
      wtcs_accepted_after_payment =
        wto.accepted_website_translation_contracts.
        where("website_translation_contracts.accepted_by_client_at > '#{pmt.created_at.to_s(:db)}'")
      if wtcs_accepted_before_payment.maximum(:amount) < wtcs_accepted_after_payment.maximum(:amount)
        logger.info '-------- ASSIGN_TO_ME_PROBLEM: The client accepted the ' \
                    "bid of a more expensive translator (#{@user.id}) after " \
                    "paying for CmsRequest #{@cms_request.id}. When the " \
                    'translator tried to take the job, the PendingMoneyTransaction ' \
                    "amount (#{reserved_amount_for_translation_job}) was not " \
                    "enough to cover the CmsRequest cost (#{translation_job_cost}). " \
                    'See icldev-2874.'
        flash[:notice] = 'An error has occurred. Please open a support ticket including the following error code: 100002.'
      else
        # The issue was NOT caused by the client accepting a more expensive
        # translator after paying. It is a bug.
        logger.info "-------- ASSIGN_TO_ME_PROBLEM: Translator #{@user.id} tried " \
                    "to take CmsRequest #{@cms_request.id} but failed due to the amount " \
                    "(#{reserved_amount_for_translation_job}) of the " \
                    'PendingMoneyTransaction not being enough to cover ' \
                    "the CmsRequest cost (#{translation_job_cost}). This is a bug."
        flash[:notice] = 'An error has occurred. Please open a support ticket including the following error code: 100001.'
        redirect_to controller: :translator
        return
      end
    end

    # get ready with the source money account
    money_account = project.client.find_or_create_account(DEFAULT_CURRENCY_ID)

    @assigned_languages = []
    requested_cms_target_languages.each do |cms_target_language|
      ok = false
      bid = nil
      rl = nil
      # --- step 1: create the bid, but don't auto-accept yet
      CmsTargetLanguage.transaction do
        begin
          rl = RevisionLanguage.where(revision_id: revision.id, language_id: cms_target_language.language_id).first
          rl = RevisionLanguage.create!(revision_id: revision.id, language_id: cms_target_language.language_id) unless rl

          unless rl.managed_work
            reviewer_id = wto.managed_work && wto.managed_work.translator_id
            managed_work = ManagedWork.new(active: MANAGED_WORK_INACTIVE, translation_status: MANAGED_WORK_CREATED)
            managed_work.owner = rl
            managed_work.from_language = @cms_request.language
            managed_work.to_language = cms_target_language.language
            managed_work.client = project.client
            managed_work.notified = 0
            unless reviewer_id == @user.id
              managed_work.translator_id = reviewer_id
            end
            managed_work.save
          end
          rl.reload

          unless @chat
            @chat = revision.chats.where(translator_id: @user.id).first
            unless @chat
              @chat = Chat.create!(revision_id: revision.id, translator_id: @user.id, translator_has_access: 0)
              logger.info "----------- created chat: #{@chat.id} for user #{@user.nickname}"
            end
          end

          # add the user note in the project chat
          unless @cms_request.note.blank?
            message = Message.new(body: @cms_request.note)
            message.user = revision.project.client
            message.owner = @chat
            message.save
          end

          if @chat.bids.length == 0
            # Bid is created wuth amount=0 when using a private translator
            logger.info "BID AMOUNTS: #{bid_amounts.inspect}"
            bid = Bid.create!(chat_id: @chat.id, revision_language_id: rl.id, status: BID_GIVEN,
                              amount: bid_amounts[cms_target_language.id], currency_id: DEFAULT_CURRENCY_ID, won: 0)
            logger.info "------------ created bid: #{bid.id}"
          else
            bid = @chat.bids[0]
            logger.info "------------ reusing existing bid: #{bid.id}"
          end
          ok = true

          revision.reload
        rescue => e
          logger.info '------------ rescuing and destroying chat'
          logger.info e.backtrace.join("\n")
          logger.info e.inspect
          logger.info bid.inspect
          @chat.destroy if @chat
          @chat = nil
        end
      end
      # --- step 2: if there is enough money, accept the bid, otherwise, create the invoice and mark it as pending payment
      next unless ok

      transfer_money!(money_account, bid, cms_target_language, translation_job_cost, rl)
    end

    if @assigned_languages.empty? && @chat
      logger.info '-------- ASSIGN_TO_ME_PROBLEM: destroying chat'
      @chat.destroy
      @chat = nil
    end

    # quit if this didn't succeed
    unless @chat
      flash[:notice] = 'There were problems assigning you this project'
      logger.info '-------- ASSIGN_TO_ME_PROBLEM: chat'
      redirect_to controller: :translator
      return
    end

    if @assigned_languages
      @header = 'Successfully Assigned the Project to You'
      @cms_request.revision.update_track_by_user(@cms_request.revision.project.client.id)
      @cms_request.revision.update_track_by_user(@user.id)

      # notify the CMS that the project's translation has started
      unless @cms_request.notify_translation_started
        logger.info '--------- could not notify the CMS about the translation'
      end
    else
      @header = 'There were problems assigning you this project'
    end

    if @embedded
      flash[:add_refresh_div] = true
      flash[:notice] = if @cms_request.block_in_ta_tool?
                         'This project is available for translation in Web Translation Editor'
                       else
                         'Click on the Refresh button in Translation Assistant to receive the project.'
                       end

      logger.info '-------- ASSIGN_TO_ME_PROBLEM: embedded'
      redirect_to controller: :chats, action: :show, project_id: @chat.revision.project_id, revision_id: @chat.revision_id, id: @chat.id
    end
  end

  def transfer_money!(money_account, bid, cms_target_language, transfer_amount, revision_language)
    # (ta + ra) is sometimes float sometimes big decimal...
    # Added .to_d (a Float method) to BigDecimal...
    # God, forgive me.
    if money_account.balance >= transfer_amount.to_d
      bid_account = bid.find_or_create_account
      MoneyTransactionProcessor.transfer_money(money_account, bid_account, transfer_amount, bid.currency_id, TRANSFER_DEPOSIT_TO_BID_ESCROW)
      bid.update_bid_to_accepted

      cms_target_language.status = CMS_TARGET_LANGUAGE_ASSIGNED
      cms_target_language.translator = @user
      StaleObjHandler.retry { cms_target_language.save! }

      # Review
      website_translation_contract = @cms_request.locate_contract(cms_target_language.language)
      wto_managed_work = website_translation_contract.website_translation_offer.managed_work

      # The new WPML client flow (for WPML 3.9+) uses a new CmsRequest attribute
      # called "review_enabled" to determine if review is enabled or disabled
      # for a cms_request. If this attribute is present (not nil), use it and
      # ignore all other ways to determine if review is enabled or disabled.
      enable_review = if !@cms_request.review_enabled.nil?
                        @cms_request.review_enabled
                      else
                        # The reviewer (wto_managed_work.translator) cannot be the same as the
                        # primary translator (the @user who clicked the "start translation" button
                        # which triggered this method).
                        wto_managed_work &&
                          wto_managed_work.active == MANAGED_WORK_ACTIVE &&
                          wto_managed_work.translator != @user
                      end

      # cms_request.revision.revision_language.first.managed_work.active is used
      # in most places of the legacy code to determine whether review is enabled
      # or disabled for a cms_request. This should be refactored when possible.
      revision_language.managed_work.update(active: enable_review)

      @assigned_languages << cms_target_language
    else
      logger.info "-------- ASSIGN_TO_ME_PROBLEM: Not enought money on client account #{money_account.balance} < #{(transfer_amount + rental_amount)}"
      bid.destroy
    end
  end

  # Request made by TAS, TAS_server_comm.py#upload_xliff_output
  def deliver
    Rails.logger.info 'Delivering'
    unless params[:file]
      set_err("Missing file attribute on parameters: #{params.inspect}")
      return
    end

    Rails.logger.info 'file correct'
    xliff = Xliff.new(uploaded_data: params[:file], translated: true)
    unless xliff.save
      set_err('Not a valid file')
      return
    end

    # @ToDo TO REMOVE: Temporal fix for xliff without xml_header
    xliff.fix_xml_header

    Rails.logger.info 'add xliff'
    @cms_request.xliffs << xliff

    Rails.logger.info 'call deliver'
    begin
      Rails.logger.info @cms_request.deliver
    rescue TranslationProxy::Notification::TPError => e
      Rails.logger.info 'ERROR DELIVERING JOB'
      set_err(e.message)
      return
    end
    Rails.logger.info 'finished'
    respond_to :xml
  end

  def notify_cms_delivery
    unless request.format == Mime[:json]
      head :not_acceptable
      return
    end

    complete_cms(@cms_request)

    respond_to { |format| format.json }
  end

  def xliff
    xliff = if params[:version] == 'untranslated'
              @cms_request.base_xliff
            elsif params[:version] == 'translated'
              @cms_request.xliffs.where(translated: true).last
            else
              @cms_request.xliffs.last
            end

    unless xliff
      set_err('Cannot locate cms_upload')
      return
    end

    if params[:inline]
      render inline: xliff.get_contents, content_type: 'text/plain', status: :ok
    else
      send_file(xliff.full_filename)
    end
  end

  def cms_upload
    cms_upload = @cms_request.cms_uploads.where(id: params[:cms_upload_id]).first
    unless cms_upload
      set_err('Cannot locate cms_upload')
      return
    end
    send_file(cms_upload.full_filename)
  end

  def store_output
    language_id = params[:language_id].to_i
    attached_data = params[:cms_download]
    title = params[:title]
    cms_target_language = @cms_request.cms_target_languages.where(language_id: language_id).first
    unless cms_target_language
      set_err('cannot locate this language ID')
      return
    end

    cms_target_language.update_attributes!(title: title) unless title.blank?

    existing_download = cms_target_language.cms_downloads.where(description: attached_data['description']).first
    existing_download.destroy if existing_download
    cms_download = CmsDownload.new(attached_data)
    cms_download.cms_target_language = cms_target_language
    cms_download.user = @user
    if cms_download.save
      @result = { 'message' => 'Download created', 'id' => cms_download.id }
    else
      cms_request.destroy
      @result = { 'message' => 'Download failed' }
    end

    respond_to do |format|
      format.html
      format.xml
    end
  end

  def cms_download
    conds = params[:description] ? { description: params[:description] } : nil
    @cms_download = @cms_target_language.cms_downloads.where(conds).first
    unless @cms_download
      set_err('cannot locate this download')
      return
    end
    respond_to do |format|
      format.html { send_file(@cms_download.full_filename) }
      format.xml
    end
  end

  def update_status
    if has_cms_completed_by_webta?(@cms_request)
      Rails.logger.info("WebTA completed #{params.inspect}")
      @cms_request.update_attributes(status: CMS_REQUEST_RELEASED_TO_TRANSLATORS, pending_tas: false)
    else
      status = params[:status].to_i
      if locate_target_language_by_name(true)
        @cms_target_language.update_attributes(status: status)
      else
        @cms_request.update_attributes(status: status)
        if [CMS_REQUEST_DONE, CMS_REQUEST_TRANSLATED].include?(status)
          @cms_request.unblock_if_need!
        end
      end
    end

    @result = { 'message' => 'Status updated' }
    respond_to do |format|
      format.html
      format.xml
    end
  end

  def update_permlink
    ok = if locate_target_language_by_name(true)
           @cms_target_language.update_attributes(permlink: params[:permlink])
         else
           @cms_request.update_attributes(permlink: params[:permlink])
         end
    @result = if ok
                { 'message' => 'Permlink updated', :permlink => params[:permlink] }
              else
                { 'message' => 'Permlink not updated' }
              end
    respond_to do |format|
      format.html
      format.xml
    end
  end

  def update_languages
    to_languages = get_to_languages

    if to_languages.empty?
      set_err('Destination languages not specified')
      return false
    end

    new_langs = 0
    to_languages.each do |lang|
      next if @cms_request.cms_target_languages.find_by(language_id: lang.id)
      cms_target_language = CmsTargetLanguage.new(status: CMS_TARGET_LANGUAGE_CREATED)
      cms_target_language.cms_request = @cms_request
      cms_target_language.language = lang
      cms_target_language.save!
      new_langs += 1
    end

    @result = { 'message' => 'Languages updated', :count => new_langs }

    respond_to do |format|
      format.html
      format.xml
    end
  end

  def notify_tas_done
    @cms_request.pending_tas = 0

    if (@cms_request.last_operation == LAST_TAS_COMMAND_OUTPUT) && ((@website.notifications & WEBSITE_NOTIFY_DELIVERY) != 0)
      @cms_request.completed_at = Time.now
    end
    @cms_request.save!
    @result = { 'message' => 'request cleared' }
    respond_to do |format|
      format.html { redirect_to controller: '/websites', action: :all_comm_errors, id: @website.id }
      format.xml
    end
  end

  def report_error
    @cms_request.update_attributes!(error_description: params[:error_report], status: CMS_REQUEST_FAILED)
    @result = { 'message' => 'error report set' }
    respond_to do |format|
      format.html { redirect_to action: :show, id: @cms_request.id }
      format.xml
    end
  end

  def destroy
    # This des
    cancel_result = @cms_request.cancel_translation

    if cancel_result[:success]
      @result = { 'message' => 'Deleted' }
    else
      set_err('Cannot delete: %s' % cancel_result[:error])
      return
    end
    respond_to do |format|
      format.html do
        flash[:notice] = @result['message']
        redirect_to action: :index
      end
      format.xml
    end
  end

  def reset
    if @user.has_supporter_privileges?
      @cms_request.reset!
      @cms_request.retry_tas
      @result = { 'message' => 'CmsRequest has been reset and a request to process it again was sent to TAS' }
    else
      set_err('Cannot reset')
      return
    end
    respond_to do |format|
      format.html do
        flash[:notice] = @result['message']
        redirect_to action: :show
      end
    end
  end

  def cancel_multiple_translations
    CmsRequest.where(id: params[:cancellable_jobs]).each(&:cancel_translation)
    redirect_to :back
  end

  def cancel_translation
    force_cancel = (params[:force_cancel].to_i == 1) # TAS send force_cancel = 1
    cancel_result = @cms_request.cancel_translation(force_cancel)

    # @ToDO When TAS cancel translation due to parse error it sends msg and body as arguments

    if cancel_result[:success]
      @result = { 'message' => 'Deleted' }
      message = _('Translation canceled')
    else
      @result = { 'message' => 'Cannot cancel this job. Reason: %s' % cancel_result[:error] }
      message = _('Could not cancel translation: %s') % cancel_result[:error]
    end

    respond_to do |format|
      format.html do
        flash[:notice] = message
        redirect_to action: :index
      end
      format.xml
    end
  end

  def debug_complete
    unless %w(test development sandbox).include?(Rails.env)
      set_err('Does not work in production mode')
      return
    end

    # --- assign the project to the translator ---

    # find the translator
    begin
      translator = Translator.find(params[:translator_id].to_i)
    rescue
      set_err("Cannot find translator #{params[:translator_id]}")
      return
    end

    revision = @cms_request.revision
    if !revision || (@cms_request.status != CMS_REQUEST_RELEASED_TO_TRANSLATORS)
      set_err('The project is not fully set up yet')
      return
    end

    logger.info ' ---------- updating target languages to assigned '
    @cms_request.cms_target_languages.each do |cms_target_language|
      cms_target_language.translator = translator
      cms_target_language.status = CMS_TARGET_LANGUAGE_ASSIGNED
      cms_target_language.save!
    end

    chat = Chat.create!(revision_id: revision.id, translator_id: translator.id, translator_has_access: 0)
    logger.info " ----------- created chat.#{chat.id}"

    @cms_request.cms_target_languages.each do |cms_target_language|
      rl = RevisionLanguage.where(revision_id: revision.id, language_id: cms_target_language.language_id).first
      rl = RevisionLanguage.create!(revision_id: revision.id, language_id: cms_target_language.language_id) unless rl
      bid = Bid.create!(chat_id: chat.id, revision_language_id: rl.id, status: BID_ACCEPTED,
                        amount: 0, currency_id: DEFAULT_CURRENCY_ID, won: 1)
      logger.info "------------ created bid: #{bid.id}"
    end

    version = @cms_request.revision.versions[0]

    logger.info ' ---------- creating a new completed version '
    generated_version = auto_complete_version(version, translator)

    unless generated_version
      set_err('Completed version could not be generated')
      return
    end

    @result = { 'message' => 'Completed the new version OK' }

    respond_to do |format|
      format.html
      format.xml
    end
  end

  def chat
    lang_name = params[:lang]

    if lang_name.blank?
      set_err('Language not specified')
      return
    end

    language = Language.where(name: lang_name).first
    unless language
      set_err('This language does not exist')
      return
    end

    unless @cms_request.revision
      set_err('CMS request not completed processing yet')
      return
    end

    revision_language = @cms_request.revision.revision_languages.where(language_id: language.id).first

    if !revision_language || !revision_language.selected_bid
      set_err('This language is not being translated')
      return
    end

    chat = revision_language.selected_bid.chat
    redirect_to controller: :chats, action: :show, project_id: chat.revision.project_id, revision_id: chat.revision_id, id: chat.id
  end

  def close_all_errors
    @cms_request.comm_errors.where(status: COMM_ERROR_ACTIVE).each do |comm_error|
      comm_error.update_attributes!(status: COMM_ERROR_CLOSED)
    end
    redirect_to action: :show
  end

  def redo
    @cms_request.cms_target_language.update!(status: CMS_TARGET_LANGUAGE_CREATED, translator_id: nil)
    @cms_request.update!(status: CMS_REQUEST_RELEASED_TO_TRANSLATORS)
    # Must reset the bid status because CmsRequestsController#reuses it.
    # otherwise the next translator that takes this translation job
    # (CmsRequest) will not be able to accept the bid, complete the job and get paid.
    @cms_request.revision.revision_languages.first.selected_bid.update!(status: BID_GIVEN)
    flash[:notice] = 'Job released to other translators'
    redirect_to action: :show
  end

  def resend
    if @cms_request.tp_id
      @cms_request.deliver
    else
      @cms_request.update_attributes(pending_tas: 1)
      retry_cms_request(@cms_request, logger)
    end

    flash[:notice] = 'Job sent again. Please allow up to 30 seconds for delivery in your CMS.'
    redirect_to request.referer
  end

  def update_cms_id
    permlink = params[:permlink]
    from_language = Language.where(name: params[:from_language]).first
    to_language = Language.where(name: params[:to_language]).first
    cms_id = params[:cms_id]
    dry_run = !params[:dry_run].blank?
    ok = false
    if permlink && from_language && to_language && cms_id
      ok = true
      @cms_requests = @website.cms_requests.joins(:cms_target_languages).where(['(cms_requests.permlink=?) AND (cms_requests.language_id=?) AND (cms_target_languages.language_id=?)', permlink, from_language.id, to_language.id])
      @cms_requests.each do |cms_request|
        cms_request.update_attributes(cms_id: cms_id) unless dry_run
      end
    end

    unless ok
      set_err('Missing arguments')
      return
    end

    respond_to do |format|
      format.html
      format.xml
    end
  end

  def get_html_output
    begin
      output = @cms_request.html_output(@cms_target_language)
    rescue CmsRequest::NotTranslated => e
      return set_err("cannot generate html output: #{e.message}")
    end

    if params[:inline]
      @output = output
      render layout: false
    else
      send_data(output,         filename: 'job_%d_%s.html' % [@cms_request.id, @cms_target_language.language.name],
                                type: 'text/plain',
                                disposition: 'downloaded')
    end
  end

  def toggle_tmt_config
    @cms_request.toggle_tmt_config
  end

  def toggle_force_ta
    @cms_request.toggle_force_ta
  end

  private

  def get_to_languages
    to_languages = []
    lang_idx = 1
    cont = true
    while cont
      lang_name = params["to_language#{lang_idx}"]
      if !lang_name.blank?
        to_language = Language.find_by(name: lang_name)
        unless to_language
          set_err('Language name is invalid: ?', lang_name)
          return false
        end
        to_languages << to_language
        lang_idx += 1
      else
        cont = false
      end
    end

    to_languages
  end

  def locate_website
    @website = Website.find(params[:website_id].to_i)
  rescue
    set_err('Cannot locate website')
    return false
  end

  def locate_request
    @cms_request = if params[:api_version] == '1.0'
                     CmsRequest.find_by(tp_id: params[:id])
                   else
                     CmsRequest.find_by(id: params[:id])
                   end

    if @cms_request.nil?
      set_err('Cannot locate request')
      return false
    end

    if @cms_request.website != @website
      set_err("Request doesn't belong to this website")
      false
    end
  end

  def locate_target_language_by_name(is_optional = false)
    @language = Language.where(name: params[:language]).first
    unless @language
      set_err('cannot find this language') unless is_optional
      return false
    end
    @cms_target_language = @cms_request.cms_target_languages.where(language_id: @language.id).first
    unless @cms_target_language
      set_err('cannot locate this output language') unless is_optional
      return false
    end

    true
  end

  def verify_translator
    if @user[:type] != 'Translator'
      set_err('You cannot access this page')
      false
    end
  end

  def verify_client
    unless @user.has_client_privileges? || @user.has_supporter_privileges?
      set_err('You cannot access this page')
      false
    end
  end

  def authorize_user
    raise Error::NotAuthorizedError unless @user
    if @user.is_a?(Translator)
      # Translator permissions are per cms_request. They can only see the
      # CmsRequests of the language pairs they were assigned in a given website.
      #
      # A website's CmsRequests listing (index page) should not be accessed by
      # translators. He can see the list of CmsRequests to translate at
      # /translator and/or /translator/open_work.
      return if params[:action] != 'index' && @cms_request&.translator_can_view?(@user)
    else
      # Client permissions are per website. The #can_view? method is implemented
      # in the Client, Alias, Admin and Supporter models.
      return if @user.can_view?(@website)
    end
    raise Error::NotAuthorizedError
  end

  def setup_user_optional
    accesskey = params[:accesskey]

    if accesskey
      if accesskey == @website.accesskey
        @user = @website.client
      else
        set_err('cannot access')
        return false
      end
    else
      if setup_user
        if (@user[:type] == 'Client') && (@website.client != @user)
          set_err("Website doesn't belong to you")
          return false
        end
      else
        return false
      end
    end
  end

  # This action was only called 2 times within the last 14 days (Feb 19 2018)
  # Checked the logs with: zcat -f log/product* | grep -a 'CMS Request being created from WPML 3.1'
  def create_from_wpml_legacy
    logger.info 'CMS Request being created from WPML 3.1 <'

    # Filters
    setup_user
    return false unless locate_website
    verify_client

    # Check for presence of source language
    if params[:orig_language].blank?
      logger.info '------ Source language not specified'
      set_err('Source language not specified')
      return false
    end

    # Check for existence of source language
    orig_language = Language.find_by(name: params[:orig_language])
    unless orig_language
      logger.info "------ cannot find this language: #{params[:orig_language]}"
      set_err('cannot find this language')
      return false
    end

    # Check for to languages
    lang_names = params.to_h.find_all { |k, _v| k.to_s =~ /to_language\d+/ }.map { |_k, v| v }
    to_languages = lang_names.map { |l| Language.find_by(name: l) }
    if to_languages.include? nil
      logger.info "------ Language name is invalid: #{lang_name}"
      set_err('Language name is invalid: ?', lang_name)
      return false
    end

    # Check for existence of at least one to language
    if to_languages.empty?
      logger.info "------ Destination languages not specified: #{lang_name}"
      set_err('Destination languages not specified')
      return false
    end

    # get the meta fields
    metas_names = params.to_h.find_all { |k, _v| k.to_s =~ /meta_name\d+/ }.map { |_k, v| v }
    metas_values = params.to_h.find_all { |k, _v| k.to_s =~ /meta_value\d+/ }.map { |_k, v| v }
    metas = []
    1.upto([metas_names.size, metas_values.size].min) do |i|
      metas << [params["meta_name#{i}"], params["meta_value#{i}"]]
    end

    # see if a cms_request with this key already exists
    cms_request = nil
    unless params[:key].blank?
      cms_request = @website.cms_requests.where(idkey: params[:key]).first
    end

    if !cms_request
      title = params[:title].blank? ? 'Document' : params[:title]
      cms_request = CmsRequest.new(status: CMS_REQUEST_CREATING, language_id: orig_language.id,
                                   cms_id: params[:cms_id],
                                   title: title, permlink: params[:permlink],
                                   tas_url: params[:tas_url], tas_port: params[:tas_port],
                                   list_type: params[:list_type], list_id: params[:list_id],
                                   note: params[:note],
                                   container: params[:container],
                                   notified: 0,
                                   idkey: params[:key])
      cms_request.website = @website
      cms_request.save!

      translator_id = params[:translator_id].to_i
      to_languages.each do |lang|
        translator = nil
        if translator_id > 0
          website_translation_contract = @website.website_translation_contracts.
                                         joins(:website_translation_offer).
                                         where(['(website_translation_offers.from_language_id = ?) AND (website_translation_offers.to_language_id = ?) AND (website_translation_contracts.translator_id=?) AND (website_translation_contracts.status=?)',
                                                orig_language.id, lang.id, translator_id, TRANSLATION_CONTRACT_ACCEPTED]).first

          if website_translation_contract
            translator = website_translation_contract.translator
          end
        end

        cms_target_language = CmsTargetLanguage.new(status: CMS_TARGET_LANGUAGE_CREATED)
        cms_target_language.cms_request = cms_request
        cms_target_language.language = lang
        cms_target_language.translator = translator
        cms_target_language.save!
      end

      doc_count = params[:doc_count].to_i

      attachment_id = 1
      loop do
        attached_data = params["file#{attachment_id}"]
        if !attached_data.blank? && !attached_data[:uploaded_data].blank?
          begin
            cms_upload = CmsUpload.new(attached_data)
            cms_upload.cms_request = cms_request
            cms_upload.user = @user
            attachment_id += 1
            break unless cms_upload.save
          rescue
            break
          end
        else
          break
        end
      end

      if attachment_id == (doc_count + 1)
        cms_request.reload
        cms_request.update_attributes(status: CMS_REQUEST_WAITING_FOR_PROJECT_CREATION)
        @result = { 'message' => 'Upload created', 'id' => cms_request.id }

        tas_comm = TasComm.new
        @tas_request_notification_sent = true # for testing
        @tas_session = tas_comm.notify_about_request(cms_request, 0, logger)
        logger.info "---- Sent TAS notification for cms_request.#{cms_request.id}. tas_session.id=#{@tas_session}"
      else
        cms_request.destroy
        @result = { 'message' => 'Upload failed' }
        logger.info "---- Upload failed. Expecting #{doc_count} attachments, got #{attachment_id - 1}"
      end

      # add meta fields
      metas.each do |meta|
        cms_request_meta = CmsRequestMeta.new(name: meta[0], value: meta[1])
        cms_request_meta.cms_request = cms_request
        cms_request_meta.save
      end

    else
      # sending output notification for the completed CMS request, so that the CMS has the translation
      retry_cms_request(cms_request, logger)
      @result = { 'message' => 'Upload created', 'id' => cms_request.id, 'duplicate' => true }
    end

    respond_to do |format|
      format.html
      format.xml
    end
  end

  # Check if a WordPress page was already sent for translation before and the
  # translation of that previous job was completed with WebTA.
  def has_cms_completed_by_webta?(cms)
    parent_cms_records = CmsRequest.where(website_id: cms.website_id, cms_id: cms.cms_id).
                         where('id < ?', cms.id).order(id: :asc).to_a
    parent_cms_records.any? { |p| completed_parent_cms_request?(cms, p) }
  end

  # Check if the previous cms_request was translated with webta
  def completed_parent_cms_request?(cms, parent_cms)
    translated_xliff = parent_cms.xliffs.select(&:translated?).last
    return false unless translated_xliff

    parsed_xliff = parent_cms.base_xliff&.parsed_xliff
    return false unless parsed_xliff

    parsed_mrk = parsed_xliff.xliff_trans_unit_mrks.find { |x| x.mrk_type == 0 }
    parsing_period = (parsed_mrk.created_at - cms.created_at)
    return false if parsing_period >= 2.weeks

    xml = Nokogiri::XML(translated_xliff.get_contents)
    cdata_targets = xml.css('target').map { |x| x.children.select(&:cdata?).present? }
    return false unless cdata_targets.all?

    parent_cms&.base_xliff&.parsed_xliff&.all_mrk_completed?
  rescue StandardError => ex
    Logging.log_error(ex)
    return false
  end

  def complete_cms(cms_request)
    authenticate_project
    cms_request.complete!
    cms_request.cms_target_language.update_attributes(status: CMS_TARGET_LANGUAGE_DONE)
    cms_request.comm_errors.each(&:close)
  end
end
