class SupporterController < ApplicationController
  include ::RefundCredit

  prepend_before_action :setup_user
  before_action :verify_admin, only: [:tasks, :requested_withdrawals, :do_mass_payments, :bidding_closing, :work_completing, :clean_old_sessions, :clean_old_captchas]
  before_action :verify_supporter, except: [:tasks, :requested_withdrawals, :do_mass_payments, :bidding_closing, :work_completing, :clean_old_sessions, :clean_old_captchas]
  before_action :create_reminders_list
  before_action :setup_search_filter, only: [:cms_projects, :text_resources, :anon_project]
  layout :determine_layout

  def index
    @header = 'Support Dashboard'

    @todo_things = []

    @offers_without_translators = WebsiteTranslationOffer.offers_without_translators
    @offers = WebsiteTranslationOffer.offers_for_supporter

    @open_issues = Issue.joins(:target).where('(issues.status != ?) AND (issues.updated_at < ?) AND (users.type = ?)', ISSUE_CLOSED, Time.now - 2.days, 'Translator')

    add_if_not_zero(@todo_things,
                    WebsiteTranslationOffer.count_of_no_accepted_contracts,
                    'Website translation projects to auto-assign', 'language pair', 'language pairs', action: :manage_website_project_auto_assign)

    add_if_not_zero(@todo_things,
                    @offers_without_translators.length,
                    'Website translation projects without any translators', 'offer', 'offers', action: :website_translation_offers, without_translator: 1)

    add_if_not_zero(@todo_things,
                    MoneyTransaction.requested_payments_count,
                    'Requested withdrawals', 'withdrawal', 'withdrawals', action: :requested_withdrawals)

    add_if_not_zero(@todo_things,
                    WebMessage.old_untranslated.length,
                    'Instant Translation projects pending for more than 1 hour.', 'message', 'messages', action: :web_messages)

    # add_if_not_zero(@todo_things,
    #           CmsRequest.stuck_requests.length,
    #           "Stuck CMS documents (more than #{MAX_COMM_ERRORS} errors)", 'document','documents', {:action=>:stuck_requests})

    # add_if_not_zero(@todo_things,
    #           CmsRequest.incomplete_requests.length,
    #           "Incomplete CMS documents", 'document','documents', {:action=>:incomplete_requests})

    add_if_not_zero(@todo_things,
                    IdentityVerification.where("(status = #{VERIFICATION_PENDING}) AND ((verified_item_type='UserDocument') OR (verified_item_type='ZippedFile'))").count,
                    'User identity verifications', 'request', 'requests', action: :identity_verifications)

    add_if_not_zero(@todo_things,
                    TranslatorLanguage.where("status='#{TRANSLATOR_LANGUAGE_REQUEST_REVIEW}'").count,
                    'Translation language requests', 'request', 'requests', action: :language_verifications)

    add_if_not_zero(@todo_things,
                    Arbitration.where("(type_code IN (#{[SUPPORTER_ARBITRATION_CANCEL_BID, SUPPORTER_ARBITRATION_WORK_MUST_COMPLETE].join(',')})) AND (status != #{ARBITRATION_CLOSED}) AND (supporter_id is NULL)").count,
                    'New arbitrations', 'arbitration', 'arbitrations', controller: :arbitrations, action: :pending)

    add_if_not_zero(@todo_things,
                    @offers.length,
                    'Website translation offers', 'offer', 'offers', action: :website_translation_offers)

    new_support_tickets_count = SupportTicket.where('supporter_id IS NULL').order('id DESC').count
    my_pending_tickets_count = @user.support_tickets.where(status: SUPPORT_TICKET_WAITING_REPLY).count

    add_if_not_zero(@todo_things,
                    new_support_tickets_count + my_pending_tickets_count,
                    'Support tickets by registered users', 'ticket', 'tickets', controller: :support, action: :supporter_index)

    add_if_not_zero(@todo_things,
                    @open_issues.length,
                    'Open issues for translators', 'open issue', 'open issues', action: :open_issues)
  end

  def manage_fixed_rates
    @header = 'Manage Fixed Rates'
  end

  def language_price_details
    @language = LanguagePairFixedPrice.find(params[:id])
  end

  def language_verifications
    @header = 'Pending translation language requests'
    @new_translator_languages = TranslatorLanguage.where("status='#{TRANSLATOR_LANGUAGE_REQUEST_REVIEW}'")
  end

  def identity_verifications
    @header = 'Pending identity verifications'
    @new_identity_verifications = IdentityVerification.where("(status = #{VERIFICATION_PENDING}) AND ((verified_item_type='UserDocument') OR (verified_item_type='ZippedFile'))")
  end

  def tasks
    @header = 'Perform administrative tasks'
    @tasks = [['Requested withdrawals', url_for(action: :requested_withdrawals), (MoneyTransaction.requested_payments_count > 0)],
              ['Bidding closing on revision', url_for(action: :bidding_closing), true],
              ['Work needs to complete', url_for(action: :work_completing), true],
              ['Clear old user sessions', url_for(action: :clean_old_sessions), true],
              ['Clear old captcha images', url_for(action: :clean_old_captchas), true],
              ['Refund leftover from completed software localization jobs', url_for(action: :refund_resource_language_credits), true]]
  end

  def requested_withdrawals
    @header = 'Requested withdrawals'
    @requested_transactions = MoneyTransaction.requested_payments

    @total = 0
    for transaction in @requested_transactions
      @total += transaction.amount
    end
  end

  def do_mass_payments
    payer = MassPayer.new(MoneyTransaction.requested_payments, 'Withdrawals from ICanLocalize accounts by supporter', logger, Invoice::MASS_PAY_FOLDER, params[:fail_in_debug])
    @ok = payer.ok
    @fname = payer.save_file_name
    logger.info "@ok=#{@ok}, @fname=#{@fname}"
    if @fname
      send_file(@fname)
    else
      flash[:notice] = payer.status
      redirect_to action: :tasks
    end
  end

  def bidding_closing
    t_offset = params[:t_offset].to_i
    checker = PeriodicChecker.new(Time.now + t_offset, logger)
    checker.revisions_open_to_bids_check
    flash[:notice] = 'OK'
    redirect_to action: :tasks
  end

  def work_completing
    t_offset = params[:t_offset].to_i
    checker = PeriodicChecker.new(Time.now + t_offset, logger)
    checker.work_needs_to_end_check
    flash[:notice] = 'OK'
    redirect_to action: :tasks
  end

  def clean_old_sessions
    checker = PeriodicChecker.new(Time.now, logger)
    checker.clean_old_sessions
    flash[:notice] = 'OK'
    redirect_to action: :tasks
  end

  def clean_old_captchas
    checker = PeriodicChecker.new(Time.now, logger)
    checker.clean_old_captchas
    flash[:notice] = 'OK'
    redirect_to action: :tasks
  end

  def delete_requested_withdrawals
    request_ids = make_dict(params[:request])
    not_deleted = []

    request_ids.each do |request_id|
      logger.info " ----------- deleting transaction: #{request_id}"
      money_transaction = MoneyTransaction.find(request_id)
      if money_transaction.status == TRANSFER_REQUESTED
        reverse_money_transaction(money_transaction, TRANSFER_REVERSAL_OF_PAYMENT_TO_EXTERNAL_ACCOUNT)
      else
        logger.info " !! Not able to delete withdraw request as status is #{money_transaction.status}"
        not_deleted << money_transaction.id
      end
    end

    unless not_deleted.empty?
      flash[:notice] = "The transactions #{not_deleted.to_sentence} were not deleted as they have an invalid state (Maybe mass payment already generated?)"
    end

    redirect_to action: :requested_withdrawals
  end

  def zipped_file
    begin
      document = ZippedFile.find(params[:id].to_i)
    rescue
      document = nil
    end
    if document
      send_file(document.full_filename)
    else
      redirect_to action: :index
    end
  end

  def approve_translator_language
    update_object_status(TranslatorLanguage, TRANSLATOR_LANGUAGE_APPROVED, :language_verifications) do |translator_language|
      # indicate that both the translator and language should be rescanned
      translator_language.translator.update_attributes(scanned_for_languages: 0)
      translator_language.language.update_attributes(scanned_for_translators: 0)

      # update the request
      if translator_language.translator.userstatus != USER_STATUS_CLOSED
        if translator_language.translator.can_receive_emails?
          ReminderMailer.profile_updated(translator_language.translator, "Your request to translate to #{translator_language.language.name} has been approved.").deliver_now
        end
      end
      "Approved #{translator_language.class} #{translator_language.language.name} for #{translator_language.translator.full_name}"
    end
  end

  def decline_translator_language
    update_object_status(TranslatorLanguage, TRANSLATOR_LANGUAGE_DECLINED, :language_verifications) do |translator_language|
      # indicate that both the translator and language should be rescanned
      translator_language.translator.update_attributes(scanned_for_languages: 0)
      translator_language.language.update_attributes(scanned_for_translators: 0)

      # update the request
      if translator_language.translator.can_receive_emails? && params[:quiet].blank?
        ReminderMailer.profile_updated(translator_language.translator, "Your request to translate to #{translator_language.language.name} has been declined. To have your request reviewed again, please scan and upload a translation exam result showing your skill in the language you've selected.").deliver_now
      end
      "Declined #{translator_language.class} #{translator_language.language.name} for #{translator_language.translator.full_name}"
    end
  end

  def approve_identity_verification
    update_object_status(IdentityVerification, VERIFICATION_OK, :identity_verifications) do |identity_verification|
      if identity_verification.normal_user.can_receive_emails?
        ReminderMailer.profile_updated(identity_verification.normal_user, 'Your identity was successfully verified.').deliver_now
      end
      "Approved identification for #{identity_verification.normal_user.full_name}"
    end
  end

  def decline_identity_verification
    update_object_status(IdentityVerification, VERIFICATION_DENIED, :identity_verifications) do |identity_verification|
      if identity_verification.normal_user.can_receive_emails?
        ReminderMailer.profile_updated(identity_verification.normal_user, 'Your identity could not be verified using the document you uploaded. Please make sure that you scan and upload a valid identity document and that the scan is readable.').deliver_now
      end
      "Declined identification for #{identity_verification.normal_user.full_name}"
    end
  end

  def web_messages
    @header = "Web messages that didn't get translated"
    web_messages = WebMessage.pending
    criteria1 = web_messages.select { |wm| wm.translation_status == TRANSLATION_NEEDED && wm.has_enough_money_for_translation? }
    criteria2 = web_messages.select { |wm| wm.translation_status == TRANSLATION_IN_PROGRESS }
    criteria3 = web_messages.select { |wm| wm.translation_status == TRANSLATION_NEEDS_EDIT }
    criteria4 = web_messages - criteria1 - criteria2 - criteria3
    @web_messages = criteria1 + criteria2 + criteria3 + criteria4
  end

  def batch_delete_web_messages
    failed_deletion_ids = []
    if params.key?(:web_messages_ids)
      web_messages = WebMessage.where(id: params[:web_messages_ids])
      web_messages.each do |wm|
        deleted_wm = delete_web_message(wm)
        failed_deletion_ids << wm.id unless deleted_wm
      end
      if failed_deletion_ids.any?
        flash[:error] = "The following project ids failed to be deleted [#{failed_deletion_ids.to_sentence}]"
      else
        flash[:notice] = 'Selected project(s) has been deleted!'
      end
    else
      flash[:notice] = 'No projects to delete!'
    end
    redirect_to(controller: :supporter, action: :web_messages)
  end

  def manage_website_project_auto_assign
    @header = 'Website translation projects to auto-assign'
    @translation_offers = WebsiteTranslationOffer.needs_auto_assignment
  end

  # if params[:update] = true is present here
  # it means this is an update of assigned translators/reviewers
  # translators = assigned translators/reviewers + other possible translators can be assigned
  # if not; translators = possible translator can be assigned
  def assignable_translators_to_website_translation_offers
    @offer = WebsiteTranslationOffer.find(params[:id])
    @contracts = @offer.website_translation_contracts.where(status: TRANSLATION_CONTRACT_ACCEPTED)
    @assigned_translators = @contracts.map(&:translator)
    @assigned_reviewers = @offer.managed_work.try(:translator).present? ? [@offer.managed_work.translator] : []
    @translators = Translator.autoassignable_for("#{@offer.from_language_id}_#{@offer.to_language_id}")
    @review_enabled = @offer.review_enabled_for_unstarted_jobs?
    @total_jobs = @offer.cms_requests
    @total_funded_jobs = CmsRequest.find(PendingMoneyTransaction.where('owner_type = ?  and owner_id in (?)', 'CmsRequest', @total_jobs.map(&:id)).map(&:owner_id))
    @total_word_count = @total_jobs.map(&:cms_target_language).map(&:word_count).compact.inject(0, :+)
    @total_funded_word_count = @total_funded_jobs.map(&:cms_target_language).map(&:word_count).compact.inject(0, :+)
    @total_unfunded_jobs = @offer.all_pending_cms_requests.count
  end

  def assign_translators_to_language_pair
    offer = WebsiteTranslationOffer.find(params[:website_translation_offer_id])
    @website = offer.website
    @result = offer.assign_and_create_contract(params[:translators])
  rescue => e
    set_err(e.message)
  end

  def auto_assigned_website_projects
    @header = 'Auto-assigned website projects'
  end

  def auto_assigned_website_projects_data
    query = <<-SQL
      SELECT
        wto.id,
        w.name,
        w.id          AS website_id,
        fl.name       AS from_language,
        tl.name       AS to_language,
        COUNT(
          CASE WHEN (
            ctl.status = #{CMS_TARGET_LANGUAGE_CREATED}
            AND pmt.id IS NULL
          ) THEN 1
          END
        )             AS total_unfunded,
        COUNT(
          CASE WHEN (
            ctl.status = #{CMS_TARGET_LANGUAGE_CREATED}
            AND pmt.id IS NOT NULL
          ) THEN 1
          END
        ) AS waiting_for_translator,
        COUNT(
          CASE WHEN (
            ctl.status >= #{CMS_TARGET_LANGUAGE_ASSIGNED}
            AND cms.status BETWEEN #{CMS_REQUEST_RELEASED_TO_TRANSLATORS} AND #{CMS_REQUEST_DONE}
          ) THEN 1
          END
        )             AS in_progress_and_completed,
        COUNT(cms.id) AS total_jobs,
        wto.created_at
      FROM website_translation_offers AS wto
        INNER JOIN languages AS fl
          ON wto.from_language_id = fl.id
        INNER JOIN languages AS tl
          ON wto.to_language_id = tl.id
        INNER JOIN websites AS w
          ON wto.website_id = w.id
        INNER JOIN cms_requests AS cms
          ON wto.from_language_id = cms.language_id
             AND w.id = cms.website_id
        INNER JOIN cms_target_languages AS ctl
          ON cms.id = ctl.cms_request_id
             AND ctl.language_id = wto.to_language_id
        LEFT OUTER JOIN pending_money_transactions AS pmt
          ON cms.id = pmt.owner_id AND pmt.deleted_at IS NULL
        LEFT OUTER JOIN pending_money_transactions AS dpmt
          ON cms.id = dpmt.owner_id AND dpmt.deleted_at IS NOT NULL
      WHERE wto.automatic_translator_assignment = 1
      GROUP BY wto.id
    SQL

    if params[:startDate] && params[:endDate]
      date_filter = ActiveRecord::Base.send(:sanitize_sql_array, [' HAVING wto.created_at > ? AND wto.created_at < ?', params[:startDate], params[:endDate]])
      query += date_filter
    end
    data = ActiveRecord::Base.connection.execute(query).to_a.map do |row|
      {
        id: row[0],
        website_id: row[2],
        website_name: row[1],
        from_language: row[3],
        to_language: row[4],
        jobs_unfunded: row[5],
        jobs_funded_not_started: row[6],
        jobs_in_progress: row[7],
        jobs_completed: row[8],
        created_at: row[9]
      }
    end
    respond_to do |format|
      format.html
      format.json { render json: { data: data } }
    end
  end

  def assign_assignment_type; end

  def cms_requests
    @header = 'Recent CMS documents'
    @cms_requests = CmsRequest.order('id DESC').limit(50)
    render action: :incomplete_requests
  end

  def incomplete_requests
    # TODO: add pagination
    @header = 'CMS documents that did not complete'
    @cms_requests = CmsRequest.incomplete_requests
  end

  def stuck_requests
    @header = 'Completely stuck CMS requests'
    # Todo fix this. This can return thousands of records, blocking page load - emartini 18/10/2016
    @cms_requests = CmsRequest.stuck_requests
    render(action: :incomplete_requests)
  end

  def translator_language
    @translator_language = TranslatorLanguage.find(params[:id].to_i)
    @header = "Manage #{@translator_language[:type]} #{@translator_language.language.name} for #{@translator_language.translator.full_name}"
  end

  def regenerate_available_languages
    AvailableLanguage.regenarate
    redirect_to action: :index
  end

  def remind_about_cms_projects
    checker = PeriodicChecker.new(Time.now)
    res = checker.remind_about_cms_projects(logger)
    flash[:notice] = "Sent #{res} emails"
    redirect_to action: :index
  end

  def projects
    @header = 'Projects in the system'
  end

  def cms_projects
    @header = 'Website translation projects'

    @flagged_websites = if params[:page].blank? || (params[:page] == '1')
                          Website.joins(:client).where('(websites.flag = 1) AND (users.id IS NOT NULL)').order('websites.id DESC')
                        else
                          []
                        end

    conds = []
    cond_args = []

    conds << '(websites.flag != 1) AND (users.id IS NOT NULL) AND (users.anon != 1)'

    unless @project_name.blank?
      conds << '(websites.name LIKE ?)'
      cond_args << '%' + @project_name + '%'
    end

    unless @client_name.blank?
      conds << '(users.nickname LIKE ?)'
      cond_args << '%' + @client_name + '%'
    end

    unless @category_id.blank?
      conds << '(websites.category_id = ?)'
      cond_args << @category_id
    end

    conditions = [conds.join(' AND ')] + cond_args

    websites = Website.joins(:client).where(conditions)
    @pager = ::Paginator.new(websites.count, PER_PAGE) do |offset, per_page|
      websites.limit(per_page).offset(offset).order('websites.id DESC')
    end

    @websites = @pager.page(params[:page])
    @list_of_pages = []
    for idx in 1..@pager.number_of_pages
      @list_of_pages << idx
    end
  end

  def text_resources
    @header = 'Software localization projects'

    conds = []
    cond_args = []
    unless @project_name.blank?
      conds << '(text_resources.name LIKE ?)'
      cond_args << '%' + @project_name + '%'
    end

    unless @client_name.blank?
      conds << '(users.nickname LIKE ?)'
      cond_args << '%' + @client_name + '%'
    end

    unless @category_id.blank?
      conds << '(text_resources.category_id = ?)'
      cond_args << @category_id
    end

    conditions = [conds.join(' AND ')] + cond_args

    text_resources = conditions.first.blank? ? TextResource.joins(:client) : TextResource.joins(:client).where(conditions)

    @pager = ::Paginator.new(text_resources.count, PER_PAGE) do |offset, per_page|
      text_resources.limit(per_page).offset(offset).order('text_resources.id DESC')
    end

    @text_resources = @pager.page(params[:page])
    @list_of_pages = (1..@pager.number_of_pages).to_a
  end

  def web_supports
    @header = 'Support centers'
    @web_supports = WebSupport.all.order('id ASC')
  end

  def website_translation_offers
    if params[:without_translator].blank?
      @header = 'Website translation offers'
      @offers = WebsiteTranslationOffer.offers_for_supporter
    else
      @header = 'Website translation offers without ANY translator'
      @offers = WebsiteTranslationOffer.offers_without_translators
    end
  end

  def open_issues
    params[:search] ||= ''
    params[:page] ||= 1
    params[:per] ||= 20
    @open_issues = Issue.joins(:target).order('issues.updated_at DESC').where('issues.status != ? AND users.type IN (?) AND issues.title LIKE ?', ISSUE_CLOSED, %w(Translator Client), "%#{params[:keyword]}%").page(params[:page]).per(params[:per])
  end

  def anon_projects
    @header = 'Projects by Anonymous users'

    clients = Client.joins(:websites).where('(users.anon = 1) AND (websites.id IS NOT NULL)')
    @pager = ::Paginator.new(clients.count, PER_PAGE) do |offset, per_page|
      clients.limit(per_page).offset(offset).order('users.id DESC')
    end

    @clients = @pager.page(params[:page])
    @list_of_pages = []
    for idx in 1..@pager.number_of_pages
      @list_of_pages << idx
    end
  end

  def apply_search_filter
    session[:project_name] = params[:project_name]
    session[:client_name] = params[:client_name]
    cid = params[:category_id].to_i
    session[:category_id] = cid != 0 ? cid : nil
    redirect_action = %w(cms_projects text_resources).include?(params[:continue_to]) ? params[:continue_to] : nil
    redirect_to controller: :supporter, action: redirect_action
  end

  def refund_resource_language_credits
    real_run = (params[:real_run].to_i == 1)
    @report = []
    total_refunded = 0
    ResourceChat.includes(:resource_language).where('(resource_chats.word_count = ?) AND (resource_chats.status = ?)', 0, RESOURCE_CHAT_ACCEPTED).each do |resource_chat|
      if resource_chat.resource_language &&
         resource_chat.resource_language.managed_work

        managed_work = resource_chat.resource_language.managed_work

        if managed_work.active == MANAGED_WORK_INACTIVE
          @report << [resource_chat.resource_language, 'Translated only']
          if real_run
            total_refunded += refund_resource_language_leftover_credit(resource_chat.resource_language)
          end
        elsif managed_work.translation_status == MANAGED_WORK_COMPLETE
          @report << [resource_chat.resource_language, 'Translated and reviewed']
          if real_run
            total_refunded += refund_resource_language_leftover_credit(resource_chat.resource_language)
          end
        end
      end
    end

    if real_run
      flash[:notice] = 'Refunded all these jobs. Total = %.2f' % total_refunded
      redirect_to action: :index
    end
  end

  def flags
    @users = User.where(flag: true)
    @text_resources = TextResource.where(flag: true)
    @revisions = Revision.where(flag: true)
    @websites = Website.where(flag: true)
  end

  def new_website_quote
    @website = WebsiteQuote.new
  end

  def website_quote
    attrs = params.require(:website_quote).permit(:url)

    @website = WebsiteQuote.new(attrs[:url])
    @words = @website.get_words if @website.valid?
    render action: :new_website_quote
  rescue => e
    redirect_to action: :new_website_quote, notice: e.message
  end

  def unstarted_auto_assignment_jobs
    cms_requests = CmsRequest.unstarted_auto_assignment_jobs
    @grouped_cms_requests = cms_requests.group_by(&:id)
  end

  def unfinished_translation_jobs
    cms_requests = CmsRequest.unfinished_translation_jobs

    results = []
    cms_requests.each do |cms|
      results << cms if cms.deadline_elapsed_percentage >= 85
    end
    @pager = ::Paginator.new(results.count, PER_PAGE) do |offset, per_page|
      results[offset, per_page]
    end
    @cms_requests = @pager.page(params[:page])
    @list_of_pages = (1..@pager.number_of_pages).map { |x| x }
  end

  private

  def setup_search_filter
    @project_name = session[:project_name] || ''
    @client_name = session[:client_name] || ''
    @category_id = session[:category_id] || nil
  end

  def verify_admin
    unless @user.has_admin_privileges?
      set_err('You are not authorized to view this')
      false
    end
  end

  def verify_supporter
    unless @user.has_supporter_privileges?
      set_err('You are not authorized to view this')
      false
    end
  end

  def update_object_status(objectclass, status, goto)
    begin
      object = objectclass.find(params[:id])
    rescue
      object = nil
    end
    if object
      object.update_attributes(status: status)
      flash[:notice] = yield(object)
    end
    redirect_to action: goto
  end

  def add_if_not_zero(todo_things, count, title, single_txt, plural_txt, url_hash)
    if count > 0
      todo_things << [title, "#{count} pending #{count == 1 ? single_txt : plural_txt}", url_hash]
    end
  end

  def delete_web_message(web_message)
    ok = false
    WebMessage.transaction do
      if [TRANSLATION_PENDING_CLIENT_REVIEW, TRANSLATION_NOT_NEEDED, TRANSLATION_NEEDED].include?(web_message.translation_status)
        begin
          web_message.update_attributes!(translation_status: TRANSLATION_NOT_NEEDED)
          ok = true
        rescue
        end
      end
    end
    return false unless ok
    web_message.destroy
  end

end
