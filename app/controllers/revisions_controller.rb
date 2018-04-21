class RevisionsController < ApplicationController
  include ::ProcessorLinks
  include ::CreateDeposit

  include ::ReuseHelpers
  include ::RootAccountCreate
  include ::UpdateSupporterDataAction

  layout :determine_layout

  # disable CSRF token check to be able to accept requests from WPML
  skip_before_action :verify_authenticity_token

  prepend_before_action :setup_user
  before_action :user_type_authorized?, only: :select_private_translators
  before_action :verify_ownership, except: [:lookup_by_private_key]
  before_action :setup_help
  before_action :verify_modify, only: %w(
    edit_file_upload
    edit_description
    edit_name
    edit_source_language
    edit_languages
    edit_conditions
    edit_categories
    edit_release_status
  )

  def index
    @header = _('Revisions for project: %s') % @project.name
    @revisions = @project.revisions
    respond_to do |format|
      format.html
      format.xml
    end
  end

  def create
    name = params[:name]
    language_id = params[:language_id].to_i
    private_key = params[:private_key]
    cms_request_id = params[:cms_request_id]

    unless @project.can_create_new_revisions[0] || !cms_request_id.blank?
      set_err('Revision cannot be created in this project', CANNOT_CREATE_NEW_REVISION_IN_PROJECT_ERROR)
      return
    end

    # verify that this language actually exists
    unless Language.find(language_id)
      set_err('Bad language specified', BAD_LANGUAGE_SPECIFIED_FOR_REVISION_ERROR)
      return
    end

    unless name && (name != '')
      set_err('Revision name not specified or is blank', REVISION_NAME_BLANK_ERROR)
      return
    end

    revision = Revision.new(name: name,
                            creation_time: Time.now,
                            released: 0,
                            max_bid_currency: 1,
                            language_id: language_id,
                            private_key: private_key,
                            kind: @project.kind,
                            cms_request_id: cms_request_id)

    if @project.revisions.any?
      last_revision = @project.revisions.last
      unless revision.base_copy(@project.revisions.last)
        set_err('Revision cannot be saved', REVISION_CANNOT_BE_SAVED_ERROR)
        return false
      end
    end

    @project.revisions << revision
    unless @project.save
      set_err('Project with new revision cannot be saved', REVISION_CANNOT_BE_SAVED_ERROR)
      return false
    end

    revision.track_hierarchy(@user_session, false)

    @result = { 'message' => 'Revision created', 'id' => revision.id }

    respond_to do |format|
      format.html
      format.xml
    end
  end

  def edit_file_upload
    req = params[:req]
    @show_edit_client_upload = nil
    if req == 'show'
      @show_edit_client_upload = true
    elsif req == 'del'
      @revision.versions.first.try(:destroy)
      @revision.reload
    end
  end

  def edit_name
    return unless @current_revision

    req = params[:req]
    @show_edit_name = nil # set the default value - don't show the list
    if req == 'show'
      @show_edit_name = true
    elsif req == 'save'
      @revision.update_attributes(params[:revision])
    end
  end

  def edit_conditions
    return unless @current_revision

    @show_edit_conditions = nil # set the default value - don't show the list
    case params[:req]
    when 'show'
      @show_edit_conditions = true
    when 'save'
      amount = params[:revision][:max_bid].to_f
      auto_accept_amount = params[:revision][:auto_accept_amount].to_f
      bidding_duration = params[:revision][:bidding_duration].to_i
      word_count = params[:revision][:word_count].to_i
      project_completion_duration = params[:revision][:project_completion_duration].to_i
      helpers = Object.new.extend(ActionView::Helpers::NumberHelper)

      # check if the work duration is going to be shortended and if there are selected or open bids
      if @revision.project_completion_duration.to_i > project_completion_duration &&
         (@revision.selected_bids.try(:any?) || @revision.open_bids.try(:any?))
        @warning = _("Translators have bid on your project.\nBefore you shorten the work duration, you must delete these bids.")
        return
      end

      # constraints for all projects
      if amount <= @revision.client.minimum_bid_amount
        @warning = _('You cannot set the maximum bidding amount below %.2f') % @revision.client.minimum_bid_amount
        return
      elsif word_count == 0
        @warning = _('Please enter the number of words to be translated.')
        return
      elsif auto_accept_amount > amount
        @warning = _('Auto accept amount cannot be higher than maximal bidding amount')
        return
      elsif bidding_duration < 1
        @warning = _('You must allow at least one day for bidding')
        return
      elsif project_completion_duration < 1
        @warning = _('You must allow at least one day to complete the work')
        return

      # constraint for pay whole amount projects, not pay per word
      elsif !@revision.pay_per_word? && ((auto_accept_amount != 0) && auto_accept_amount.to_s.to_f < (word_count * @revision.client.minimum_bid_amount).to_s.to_f)
        @warning = _('The minimum auto bid-accept amount is %s USD per word, or pick 0.00 to disable it.' % helpers.number_to_currency(@revision.client.minimum_bid_amount))
        return
      elsif !@revision.pay_per_word? && (amount.to_s.to_f < (word_count * @revision.client.minimum_bid_amount).to_s.to_f)
        @warning = _('The maximal bid amount should be equal or greater than %s USD per word. According to this, minimum valid amount is %s' % [helpers.number_to_currency(@revision.client.minimum_bid_amount), helpers.number_to_currency(word_count * @revision.client.minimum_bid_amount)])
        return
      else
        unless @revision.update_attributes(params[:revision])
          @warning = _('Something is wrong. Please correct the values you entered.')
          return
        end
      end
    end
  end

  def add_required_amount_for_auto_accept
    @required_amount = @revision.missing_amount_for_auto_accept_for_all_languages
    if @required_amount > 0
      create_deposit_from_external_account(@user, @required_amount, @revision.max_bid_currency)
    end
  end

  def edit_release_status
    return unless @current_revision

    req = params[:req]
    if (req == 'show') && (@revision.released != 1)
      @warnings = @revision.release_problems

      if @warnings.empty?
        @revision.release(params[:is_test].to_i)
        @warnings = nil
        @refresh = true

        # look for qualified translators and prepare the notifications to send
        if @revision.is_test?
          flash[:notice] = _("Project released, but not available to translators because it's a test project")

          if params[:clear_notifications]
            SentNotification.where(user_id: translator_ids, owner: @revision).delete_all
          end
        else
          flash[:notice] = _('Project released to translators')
        end
      end
    elsif @revision.released != 0
      @revision.released = 0
      @revision.save!
      @refresh = true
    end
  end

  def edit_categories
    return unless @current_revision

    case params[:req]
    when 'show'
      @show_edit_categories = true

      revision_category_ids = @revision.revision_categories.collect(&:category_id)
      @categories = Category.all.collect { |cat| [cat.id, cat.name, revision_category_ids.include?(cat.id)] }

    when 'save'
      @revision.revision_categories.destroy_all
      if params[:category]
        params[:category].keys.each { |cat_id| RevisionCategory.create!(category_id: cat_id, revision_id: @revision.id) }
      end
    end
  end

  def edit_languages
    return unless @current_revision

    case params[:req]
    when 'show'
      @show_edit_languages = true
      @languages = {}

      to_lang = Language.to_languages_with_translators(@revision.language_id, @revision.kind != TA_PROJECT)
      to_lang.each do |lang|
        @languages[lang.name] = [lang.id, false, lang.major]
      end

      for rev_lang in @revision.revision_languages
        if rev_lang.language && @languages.key?(rev_lang.language.name)
          @languages[rev_lang.language&.name][1] = true
        end
      end

    when 'save'
      begin
        to_lang_list = make_dict(params[:language])
      rescue
        to_lang_list = []
      end

      # Split the languages in groups
      cant_remove = @revision.revision_languages.find_all { |x| !to_lang_list.include?(x.language_id) && x.unfinished_bids.any? }
      to_remove = @revision.revision_languages.find_all { |x| !to_lang_list.include?(x.language_id) && x.unfinished_bids.empty? }
      to_add = to_lang_list - @revision.revision_languages.map(&:language_id)

      # issue a warning for messages that can't be removed
      if cant_remove.any?
        @warning = _("Some languages could not be removed because translators have bid on them:\n")
        cant_remove.each do |rl|
          @warning = @warning + rl.language.name + "\n"
        end
      end

      # Destroy all previous languages that can be removed
      to_remove.each(&:destroy)

      # Add all languages that aren't on the project yet
      to_add.each do |id|
        revision_language = RevisionLanguage.new(language_id: id)
        revision_language.revision = @revision
        revision_language.save

        # add translation review for that language
        managed_work = ManagedWork.new(active: MANAGED_WORK_INACTIVE,
                                       translation_status: MANAGED_WORK_CREATED,
                                       from_language_id: @revision.language_id,
                                       to_language_id: id,
                                       notified: 0)

        managed_work.client = @project.client
        managed_work.owner = revision_language
        managed_work.save!
        managed_work.wait_for_payment

      end
    end
    @revision.reload
    @revision.save!
  end

  def pay_bids_with_transfer
    unless @user.can_pay?
      set_err("You don't have permission for that")
      return
    end

    if params[:accept].try(:length) != ChatsController::BID_ACCEPT_CONDITIONS.length
      @warning = _('You must accept all contract conditions in order to continue')
      return
    end

    @revision.pending_bids.each do |bid|
      ActiveRecord::Base.transaction do
        bid.transfer_translation_escrow
        bid.accept
      end
    end
    @revision.reload

    @revision.pending_managed_works.each do |mw|
      mw.owner.selected_bid.transfer_review_escrow
      mw.activate
    end
    flash[:notice] = 'Your work will start now'
  end

  def pay_bids_with_paypal
    warning = nil
    unless @user.can_pay?
      set_err("You don't have permission for that")
      return
    end

    if params.fetch(:accept, {}).length != ChatsController::BID_ACCEPT_CONDITIONS.length
      warning = _('You must accept all contract conditions in order to continue')
      flash[:notice] = warning
    end

    invoices = []

    if @revision.pending_translation_and_review_cost > 0
      invoices << Invoice.create_for_bids(@user.money_accounts.first, @user, @revision)
    end

    if invoices.empty? || warning.present?
      redirect_to :back
      return
    end

    redirect_to paypal_pay_invoices(invoices, @user, url_for(controller: :revisions, action: :show, project_id: @project.id, id: @revision.id))
  end

  def edit_source_language
    return unless @canedit_source_language

    @show_edit_source_language = nil # set the default value - don't show the list
    req = params[:req]
    if req == 'show'
      @show_edit_source_language = true

      @languages = Language.have_translators([], (@revision.kind != TA_PROJECT))

    elsif req == 'save'
      @apply_changes = @revision.language_id != params[:revision][:language_id]
      if @apply_changes
        @revision.update_attributes(params[:revision])

        # now, set this revision's word count according to the selected project's language
        setup_stats # the statistics display will update, so we need to get them too

        @canedit_languages = @canedit && @revision.language
        @revision.reload
      end
    end
  end

  def edit_description
    return unless @canedit
    req = params[:req]
    @show_edit_description = nil # set the default value - don't show the list
    if req == 'show'
      @show_edit_description = true
    elsif req == 'save'
      @revision.assign_attributes(params[:revision])
      if @revision.valid?
        @revision.save
      else
        @warning = list_errors(@revision.errors.full_messages, false)
      end
    end
  end

  def reuse_translators
    flash[:notice] = ''

    release_problems = @revision.release_problems()
    if @revision.is_test?
      flash[:notice] = "You can't invite translators on test projects."
    elsif release_problems.any?
      flash[:notice] = "You can't invite translators because your project setup is not complete. Constraints:\n"
      flash[:notice] += release_problems.map { |x| '* ' + x }.join("\n")
    elsif @revision.revision_languages.empty?
      flash[:notice] = 'You have not selected any language yet.'
    end

    unless flash[:notice].blank?
      (request.referer.present? ? (redirect_to :back) : (render plain: ''))
      return
    end

    project_hash = JSON.parse(params[:project])
    project_to_reuse = project_hash['class'].constantize.find(project_hash['id'])

    translator_for_language = languages_and_translators_to_reuse(project_to_reuse)
    reviewer_for_language = languages_and_reviewers_to_reuse(project_to_reuse)

    missing_rls = @revision.revision_languages.find_all { |rl| rl.selected_bid.nil? }

    missing_rls.each do |rl|
      translator = translator_for_language[rl.language]
      reviewer = reviewer_for_language[rl.language]
      next unless translator
      if rl.managed_work && rl.managed_work.translator_id == translator.id
        rl.managed_work.update_attribute :translator_id, nil
      end

      chat = @revision.chats.find_by(translator_id: translator.id)

      unless chat
        chat = Chat.new(translator_has_access: 1)
        chat.revision = @revision
        chat.translator = translator
        chat.save!
      end

      rl.set_reviewer(reviewer) if reviewer

      to_who = [translator]
      to_who << reviewer if reviewer
      create_message_in_chat(
        chat,
        @revision.project.manager,
        to_who,
        "Hi, I'm inviting you to join me in this project.
        Since we already worked together on #{project_to_reuse.name}, I'd like you to bid on this project, please."
      )

      flash[:notice] += "#{translator.nickname} is invited to bid for #{rl.language.name}.\n"
    end
    flash[:notice] = 'Could not find any translator to reuse' if flash[:notice].blank?

    redirect_back(fallback_location: projects_path)
  end

  def show
    unless @user.can_view?(@project)
      set_err "You can't do this"
      return
    end

    @projects_to_reuse = projects_to_reuse if @user.has_client_privileges?

    @header = @project.name + ' - ' + @revision.name + ' ' + _('revision')
    @extra_info = params[:extra_info]
    setup_stats

    if (@project.source == SIS_PROJECT) && (@revision.versions.length >= 1)
      orig_language, @sis_stats = @revision.versions[0].get_sisulizer_stats
    end

    if @user.has_client_privileges?
      other_chats = @revision.chats.where(["EXISTS (SELECT * from messages WHERE (messages.owner_id=chats.id) AND (messages.owner_type='Chat'))"]).distinct
      @other_chats = other_chats unless other_chats.empty?
      @pending_bids = @revision.pending_bids
      @pending_managed_works = @revision.pending_managed_works
      @has_money = @user.money_account && @revision.client.money_account && (@revision.client.money_account.balance >= @revision.pending_cost)
      @transactions = []
      @pending_bids.each do |bid|
        desc = "Translation #{bid.revision_language.language.name}"
        desc += " Per Word #{bid.amount.to_f} USD" if @revision.pay_per_word?
        @transactions << { description: desc, value: bid.translator_payment }
      end
      @pending_managed_works.each do |managed_work|
        review_price_percentage = @revision.from_cms? ? REVIEW_PRICE_PERCENTAGE : 0.5
        desc = "Review #{managed_work.owner.language.name}"
        desc += " #{managed_work.owner.selected_bid.amount.to_f * review_price_percentage}" if @revision.pay_per_word?
        @transactions << { description: desc, value: managed_work.reviewer_payment }
      end
    elsif @user[:type] == 'Translator'
      @your_chat = @user.chats.where(revision_id: @revision.id).first
      if @your_chat && @your_chat.user_can_post
        @user_can_bid = (@revision.open_to_bids == 1)
      elsif !@is_reviewer && !@project.not_last_revision?(@revision) && @revision.user_can_create_chat(@user)
        if (@revision.kind != TA_PROJECT) || (@user.userstatus == USER_STATUS_QUALIFIED)
          @user_can_create_chat = true
        else
          @practice_project_needed = true
        end
      elsif @is_reviewer
        @message = _('You are reviewing translation in this project. When the client selects the translator, you will be able to get started.')
      else
        @message = @revision.chat_closed_reason
        @how_to_fix = @revision.chat_closed_link
      end
    end

    respond_to do |format|
      format.html
      format.xml
    end
  end

  def lookup_by_private_key
    private_key = params[:private_key].to_i
    @revision = Revision.includes(:project).where('revisions.private_key' => private_key).first
    if @revision
      if @revision.project.client_id != @user.id
        set_err('Not your project', ACCESS_DENIED_ERROR)
        return
      end
    else
      set_err('Revision not found', NOT_FOUND_ERROR)
      return
    end
    respond_to do |format|
      format.html
      format.xml
    end
  end

  def delete
    if @revision.can_delete_with_siblings
      @revision.delete_siblings
      @project.revisions.delete(@revision)
      @revision.destroy
      @project.destroy if @project.revisions.empty?
      @status = 'Revision deleted'
    else
      @status = 'Revision cannot be deleted now'
    end

    @result = { 'message' => @status }

    respond_to do |format|
      format.html
      format.xml
    end
  end

  def destroy
    unless @revision.can_delete?
      flash[:notice] = 'Cannot delete this project right now'
      redirect_to action: :index
      return
    end

    @revision.destroy
    @project.reload
    @project.destroy if @project.revisions.empty?
    flash[:notice] = 'Project deleted'

    redirect_to controller: :projects
  end

  def support_file
    if !params[:support_file_id].nil?
      return false unless set_support_file(params[:support_file_id])
    else
      set_err('Support file ID not specified')
      return false
    end

    respond_to do |format|
      format.html { send_file(@support_file.full_filename) }
      format.xml { render template: 'support_files/show.xml.builder' }
    end
  end

  def support_files
    @support_files = @revision.support_files
    respond_to do |format|
      format.html
      format.xml { render template: 'support_files/index.xml.builder' }
    end
  end

  def select_private_translators
    @header = _('Select a translator for this project')
    @my_translators = [["-- Don't assign --", 0]] + @user.accepted_private_translators.collect { |translator| [translator.full_real_name, translator.id] }
  end

  def review_payment_for_private_translators
    @header = _('Review and approve payment')
    @word_count = 0

    # look for the translator assignment inputs
    @selected_translators = {}
    @revision.revision_languages.each do |rl|
      inp_name = "translator_for#{rl.id}"
      next unless params.key?(inp_name)
      translator_id = params[inp_name].to_i
      if translator_id > 0
        @selected_translators[rl.id] = translator_id
        @word_count += @revision.lang_word_count(rl.language)
      end
    end

    @num_languages = @selected_translators.length
    if @num_languages == 0
      @warning = _('You have not assigned a translator to any language.')
      return
    end

    # calculate the cost per language
    stats = @revision.get_stats

    if stats.any?
      @document_count = 0
      stats[STATISTICS_DOCUMENTS][@revision.language_id].each do |code, cnt|
        @document_count += cnt if code != WORDS_STATUS_DONE_CODE
      end
    end

    @per_language_cost = 0

    @total_cost = @per_language_cost.ceil.to_f

    @total_cost = 0 if @revision.is_test == 1

    @account = @user.find_or_create_account(DEFAULT_CURRENCY_ID)
    @missing_balance = if @account.balance >= @total_cost
                         0
                       else
                         @total_cost - @account.balance
                       end

    @total_cost
  end

  # this method is used only for private translators
  def transfer_payment_for_translation
    selected_translators = params[:selected_translators]

    if selected_translators.blank?
      @warning = _("You don't have any private translators that can take this job.")
      return
    end

    @total_cost = params[:total_cost].to_f
    @currency = Currency.find(DEFAULT_CURRENCY_ID)

    @account = @revision.client.find_or_create_account(DEFAULT_CURRENCY_ID)
    root_account = find_or_create_root_account(DEFAULT_CURRENCY_ID)
    if @account.balance >= @total_cost
      MoneyTransactionProcessor.transfer_money(@account, root_account, @total_cost, DEFAULT_CURRENCY_ID, TRANSFER_PAYMENT_FOR_TA_RENTAL, fee_rate = 0)
      selected_translators.each do |rl_id, translator_id|
        rl = RevisionLanguage.find(rl_id)
        translator = Translator.find(translator_id)

        # use an existing chat or create a new one for the translator
        chat = @revision.chats.where(translator_id: translator.id).first
        unless chat
          chat = Chat.new
          chat.translator = translator
          chat.revision = @revision
          chat.save!
        end

        # create a won bid, with zero amount
        bid = Bid.new(status: BID_ACCEPTED,
                      amount: 0,
                      currency_id: DEFAULT_CURRENCY_ID,
                      accept_time: Time.now,
                      won: 1)
        bid.chat = chat
        bid.revision_language = rl
        bid.save!

        if translator.can_receive_emails?
          ReminderMailer.project_assigned(translator, bid).deliver_now
        end
      end
    else
      missing_balance = @total_cost - @account.balance

      bids = []
      selected_translators.each do |rl_id, translator_id|
        rl = RevisionLanguage.find(rl_id)
        translator = Translator.find(translator_id)

        # use an existing chat or create a new one for the translator
        chat = @revision.chats.where(translator_id: translator.id).first
        unless chat
          chat = Chat.new
          chat.translator = translator
          chat.revision = @revision
          chat.save!
        end

        # create a won bid, with zero amount
        bid = Bid.new(status: BID_GIVEN,
                      amount: 0,
                      currency_id: DEFAULT_CURRENCY_ID,
                      accept_time: Time.now,
                      won: 0)
        bid.chat = chat
        bid.revision_language = rl
        bid.save!

        bids << bid

      end

      invoice = create_invoice_for_bids(DEFAULT_CURRENCY_ID, @account, @user, @revision, bids, missing_balance)

      money_transaction = MoneyTransaction.new(amount: missing_balance,
                                               currency_id: DEFAULT_CURRENCY_ID,
                                               chgtime: Time.now,
                                               status: TRANSFER_PENDING,
                                               operation_code: TRANSFER_DEPOSIT_FROM_EXTERNAL_ACCOUNT)
      money_transaction.owner = invoice
      money_transaction.source_account = @account
      money_transaction.target_account = root_account
      money_transaction.save!

      # now, redirect to PayPal to complete the transaction
      @invoice_payment_link = paypal_pay_invoice(invoice, @user, url_for(action: :show))
    end

  end

  def invite_translator
    @header = _('Invite translators for this project')
    @revision_language = @revision.revision_languages.where('revision_languages.id' => params[:revision_language_id].to_i).first
    unless @revision_language
      set_err('cannot find language')
      return
    end

    @release_problems = @revision.release_problems

    if @release_problems.empty?
      @translators = Translator.find_by_sql("
        SELECT DISTINCT u.*
        FROM users u
        WHERE (u.type = 'Translator') AND (
          (
            (u.userstatus != #{USER_STATUS_CLOSED}) AND
            EXISTS (
              SELECT tlf.id from translator_languages tlf
              WHERE ((tlf.translator_id = u.id)
                AND (tlf.type = 'TranslatorLanguageFrom')
                AND (tlf.status = #{TRANSLATOR_LANGUAGE_APPROVED})
                AND (tlf.language_id = #{@revision.language_id}))
            ) AND
            EXISTS (
              SELECT tlt.id from translator_languages tlt
              WHERE ((tlt.translator_id = u.id)
                AND (tlt.type = 'TranslatorLanguageTo')
                AND (tlt.status = #{TRANSLATOR_LANGUAGE_APPROVED})
                AND (tlt.language_id = #{@revision_language.language_id}))
            )
          )
        ) ORDER BY u.rating DESC")
      @private_translators = Translator.find_by_sql("
        SELECT DISTINCT u.*
        FROM users u
        WHERE (u.type = 'Translator') AND (
          (
            u.userstatus = #{USER_STATUS_PRIVATE_TRANSLATOR} AND
            EXISTS (
              SELECT pt.id status from private_translators pt
              WHERE pt.client_id = #{@user.id}
                AND pt.translator_id = u.id
                AND pt.status = #{PRIVATE_TRANSLATOR_ACCEPTED}
            )
          )
        ) ORDER BY u.rating DESC")
    end
  end

  private

  def html_request?
    params[:format].nil? || params[:format] == 'html'
  end

  def user_type_authorized?
    # Only allow Client and Alias users to access an action
    if html_request? && !(%w(Client Alias).include? @user[:type])
      set_err('Only clients can access this page.')
      # Return false to prevent the action from being executed.
      false
    end
  end

  def verify_ownership
    res = do_verify_ownership(project_id: params[:project_id], revision_id: params[:id])

    return res unless res && (params[:format] != 'xml')

    @current_revision = !@project.not_last_revision?(@revision)

    @canedit =
      !@revision.cms_request &&
      @current_revision &&
      (@revision.released == 0) &&
      (@project.client_id == @user.id || (@project.client == @user.master_account && @user.can_modify?(@project)))

    @canedit_languages = @canedit && @revision.language && (@revision.kind != SIS_PROJECT)
    @canedit_source_language = @canedit && (@revision.kind != TA_PROJECT) && (@revision.kind != SIS_PROJECT)
    @canedit_source = @canedit && (@revision.kind != SIS_PROJECT)

    if !@revision.cms_request && (@user[:type] == 'Client')
      @my_translators = @user.accepted_private_translators

      @available_for_private_translators =
        (@revision.kind == TA_PROJECT) &&
        @my_translators &&
        !@my_translators.empty? &&
        !@revision.open_translation_languages.empty?

      @can_assign_to_private_translators =
        @available_for_private_translators &&
        !@revision.description.blank? &&
        @revision.project_completion_duration
    end

    res
  end

  def setup_stats
    stats = @revision.get_stats
    if stats
      @document_count = stats[STATISTICS_DOCUMENTS]
      @sentence_count = stats[STATISTICS_SENTENCES]
      @word_count = stats[STATISTICS_WORDS]
      @support_files_count = stats[STATISTICS_SUPPORT_FILES]
    end
  end

  def verify_modify
    unless @user.can_modify?(@project)
      set_err("You can't do that.")
      false
    end
  end
end
