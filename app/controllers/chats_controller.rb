class ChatsController < ApplicationController
  include ::Glossary
  include ::ProcessorLinks
  include ::Reminders
  include ::TargetUsers

  prepend_before_action :setup_user
  # disable CSRF token check to be able to accept requests from WPML
  skip_before_action :verify_authenticity_token
  before_action :verify_ownership
  layout :determine_layout
  before_action :setup_help
  before_action :verify_modify, only: [:accept_bid, :transfer_bid_payment]

  BID_ACTION_CONFIRMATION = {
    BID_ACTION_DELETE_BID => N_('Are you sure you want to delete this bid?'),
    BID_ACTION_REFUSE_BID => N_('Are you sure you want to refuse this bid?'),
    BID_ACTION_COMPLETE_REVIEW => N_('Are you sure you are done reviewing this project?')
  }.freeze

  BID_ACTION_NAMES = {
    BID_ACTION_ACCEPT_BID => N_('Accept bid'),
    BID_ACTION_FINALIZE_WORK => N_('Accept the work and release payment to translator'),
    BID_ACTION_MAKE_BID => N_('Bid on project'),
    BID_ACTION_EDIT_BID => N_('Edit bid'),
    BID_ACTION_DELETE_BID => N_('Delete bid'),
    BID_ACTION_REFUSE_BID => N_('Refuse bid'),
    BID_ACTION_CANCEL_BID => N_('Cancel bid'),
    BID_ACTION_COMPLETE_PAYMENT => N_('Check payment status'),
    BID_ACTION_DECLARE_DONE => N_('Declare the work as complete'),
    BID_ACTION_SELF_COMPLETE => N_('Declare the work as complete'),
    BID_ACTION_COMPLETE_REVIEW => N_('Review is complete'),
    BID_ACTION_ADD_REVIEW => N_('Enable review'),
    BID_ACTION_CANCEL_REVIEW => N_('Cancel review')
  }.freeze

  BID_ACTION = {
    BID_ACTION_ACCEPT_BID => 'accept_bid',
    BID_ACTION_FINALIZE_WORK => 'finalize_bid',
    BID_ACTION_MAKE_BID => 'edit_bid',
    BID_ACTION_EDIT_BID => 'edit_bid',
    BID_ACTION_DELETE_BID => 'delete_bid',
    BID_ACTION_REFUSE_BID => 'refuse_bid',
    BID_ACTION_CANCEL_BID => 'cancel_bid',
    BID_ACTION_COMPLETE_PAYMENT => 'check_invoice_status',
    BID_ACTION_DECLARE_DONE => 'declare_done',
    BID_ACTION_SELF_COMPLETE => 'declare_done',
    BID_ACTION_COMPLETE_REVIEW => 'review_complete',
    BID_ACTION_ADD_REVIEW => 'enable_review',
    BID_ACTION_CANCEL_REVIEW => 'cancel_review'
  }.freeze

  BID_ACCEPT_CONDITIONS = [
    [N_('I read and accepted the Client Agreement and with the arbitration rules for resolving conflicts'), 'http://docs.icanlocalize.com/legal', 'ICanLocalize rules']
  ].freeze

  BID_FINALIZE_CONDITIONS = [
    [N_('I read and accepted the Client Agreement'), 'http://docs.icanlocalize.com/legal/client-agreement/', 'Client Agreement'],
    [N_('I confirm that the work done by the translator is complete and to my full satisfaction'), nil, nil],
    [N_('I understand that this operation in not reversible and that I cannot make further requests regarding this work'), nil, nil]
  ].freeze

  BID_REVIEW_CONDITIONS = [
    ['I have reviewed the translation and confirm that it is ready to be delivered', 'http://docs.icanlocalize.com/?page_id=312', 'Review instructions'],
    ['I have made sure that any pending issue, raised during the review process has been handled', nil, nil]
  ].freeze

  def index
    @chats = @revision.chats
    respond_to do |format|
      format.html
      format.xml
    end
  end

  def create
    if @user.has_supporter_privileges? && params[:in_behalf_of]
      @user = User.find(params[:in_behalf_of])
    end

    chat = Chat.new(translator_has_access: 0)
    chat.revision = @revision

    if [@user, @user.master_account].include? @revision.project.client
      translator = Translator.find_by(id: params[:translator_id])
      if translator.nil?
        set_err('Cannot find this translator')
        return
      end

      other_chat = @revision.chats.find_by(translator_id: translator.id)
      if other_chat
        set_err('Translator already invited')
        return
      end

      chat.translator = translator
      # chat.translator_has_access = 1

      message = create_message_in_chat(chat, @user, [translator], "Dear #{translator.nickname}, #{@user.nickname} has invited you to apply for this project. Are you available? Looking forward to your reply.", params)

      flash[:notice] = _('%s has been successfully invited to this project. If you wish, you can add a personal message in the project chat below.') % translator.nickname

    else
      unless @revision.user_can_create_chat(@user)
        set_err('Chat cannot be created')
        return
      end

      chat.translator = @user
    end

    chat.save!
    @revision.count_track
    add_track_to_users(chat)

    if params.key?(:body)
      message = Message.new(body: params[:body], chgtime: Time.now)
      message.user = @user
      message.owner = chat
      message.save!
    end

    @result = { 'message' => 'Chat created', 'id' => chat.id }

    respond_to do |format|
      format.html { redirect_to action: :show, id: chat.id }
      format.xml
    end
  end

  def reopen
    unless @user.is_a? Supporter
      redirect_to :root
      return
    end

    @chat.bids.each do |bid|
      next unless bid.blocked?
      bid.transfer_escrow
      bid.update_attribute :status, BID_ACCEPTED
      flash[:notice] = 'Open to bid again!'
    end

    flash[:notice] ||= 'Could not reopen the bid...'
    redirect_to :back
  end

  def send_broadcast
    if params[:body].blank?
      flash[:notice] = _('No message entered')
    else
      @revision.chats.find_all(&:has_accepted_bid).each do |chat|
        next unless chat
        to_who = []
        to_who << chat.translator if chat.translator
        managed_work = chat.revision_languages.first.managed_work
        to_who << managed_work.translator if managed_work && managed_work.translator
        if to_who.any?
          message = create_message_in_chat(chat, @user, to_who, params[:body], params)
          flash[:notice] = if message.errors.blank?
                             _('Your messages were sent!')
                           else
                             list_errors(message.errors.full_messages)
                           end
        else
          flash[:notice] = _("You can't send messages as you don't have any translators selected yet").to_s.html_safe
        end
      end
    end

    redirect_to :back
  end

  def set_access
    if @user.has_client_privileges? && !@chat.has_accepted_bid
      @chat.translator_has_access = @chat.translator_has_access == 0 ? 1 : 0
      @chat.save!
    else
      set_err('You cannot change this')
      return false
    end

    @result = { 'message' => 'Chat access updated', 'id' => @chat.id }
  end

  # Note:
  #   This method is apparently not longer used. However on bidding_project_test
  #   params[lang_id] is set with a revision_language_id not with a language_id
  # BUT test_helpers send language id :)
  def edit_bid
    bid = locate_bid(params[:bid_id])
    if bid
      @bid = bid
      @lang_id = bid.revision_language.language_id
    else
      @lang_id = params[:lang_id]
      revision_language = @revision.revision_languages.find_by(language_id: @lang_id)
      @bid = Bid.new(status: BID_GIVEN, currency_id: 1, revision_language: revision_language)
    end
  end

  def save_bid
    bid = locate_bid(params[:bid_id])
    @lang_id = params[:lang_id]
    language = Language.find(@lang_id)

    if params[:do_save]
      # check that the operation is legal
      bid_disp = bids_data_per_bid(bid, language)
      if (bid_disp[BID_INFO_ACTIONS_MASK] & (BID_ACTION_MAKE_BID | BID_ACTION_EDIT_BID)) == 0
        @warning = 'This bid cannot be changed right now'
        return
      end

      if bid
        bid.update_attributes(params[:bid])
        revision_language = bid.revision_language
      else
        revision_language = RevisionLanguage.where('revision_id = ? and language_id = ?', @revision.id, @lang_id).first

        bid = Bid.new(
          params[:bid].merge(currency_id: DEFAULT_CURRENCY_ID,
                             status: BID_GIVEN,
                             chat_id: @chat.id,
                             revision_language_id: revision_language.id)
        )
      end

      unless bid.save
        @warning = bid.errors.map { |_b, v| v }.join("\n")
        return
      end

      notify_manager = true
      if bid.auto_accept?
        logger.info "Auto accepting bid ##{bid.id}"
        begin
          bid.auto_accept
          notify_manager = false
        rescue MoneyTransactionProcessor::NotEnoughFunds => e
          notify_error(e)
          @warning = "There are not enough funds in the client's account to auto-accept your bid. Your bid has been placed but you will have to wait until the client accepts it and makes a deposit before you can start working on this project."
        end
      end

      if notify_manager
        manager = bid.chat.revision.project.manager
        if manager.can_receive_emails?
          ReminderMailer.new_bid(manager, @user, bid).deliver_now
        end
      end

      create_user_reminder_for_bid(bid) if bid.status == BID_GIVEN
    end

    @bid_disp = bids_data_per_bid(bid, language)
  end

  def delete_bid
    bid = locate_bid(params[:bid_id])
    return false unless bid

    delete_all_reminders_for_bid_and_chat(bid, @chat) # first, remove the reminders for this bid
    bid.destroy

    @bid_disp = bids_data_per_bid(nil, bid.revision_language.language)
    @lang_id = bid.revision_language.language_id
  end

  def cancel_bid
    bid = locate_bid(params[:bid_id])
    return false unless bid

    bid_disp = bids_data_per_bid(bid, nil)
    if (bid_disp[BID_INFO_ACTIONS_MASK] & BID_ACTION_CANCEL_BID) == 0
      @warning = _('This bid cannot be canceled right now')
      return
    end

    bid.cancel

    @lang_id = bid.revision_language.language_id
    @bid_disp = bids_data_per_bid(bid, nil)
    @bid = bid
    @update_bid = true
  end

  def refuse_bid
    bid = locate_bid(params[:bid_id])
    return false unless bid

    bid_disp = bids_data_per_bid(bid, nil)
    if (bid_disp[BID_INFO_ACTIONS_MASK] & BID_ACTION_REFUSE_BID) == 0
      @warning = _('This bid cannot be refused right now')
      return
    end

    bid.status = BID_REFUSED
    bid.save!

    @lang_id = bid.revision_language.language_id
    @bid_disp = bids_data_per_bid(bid, nil)
    @bid = bid
    @update_bid = true
  end

  def declare_done
    bid = locate_bid(params[:bid_id])
    return false unless bid

    bid_disp = bids_data_per_bid(bid, nil)

    # if this is a CMS project, it will be completed right now, otherwise, we just set the status for the client
    reviewer = nil
    if bid.from_cms? && ((bid_disp[BID_INFO_ACTIONS_MASK] & BID_ACTION_SELF_COMPLETE) == 0)
      @warning = _('This bid cannot be declared as complete right now')
      logger.info 'This bid cannot be declared as complete right now'
      return
    end

    begin
      bid.declare_done
      @update_bid = true
    rescue MoneyTransactionProcessor::NotEnoughFunds => e
      @update_bid = false
      @warning = _('This bid cannot be declared as complete right now, please contact support.')
      @warning << "\r\n#{e.message}" if session_was_started_as_admin
    end

    # setup the parameters to update the bid control display (remove the buttons)
    @lang_id = bid.revision_language.language_id
    @bid_disp = bids_data_per_bid(bid, nil)
    @bid = bid
    respond_to do |format|
      format.html { redirect_to :back }
      format.js
    end
  end

  def open_bid_to_edit
    bid = locate_bid(params[:bid_id])
    return false unless bid

    # if this is a CMS project, it will be completed right now, otherwise, we just set the status for the client
    if @revision.cms_request && (bid.status == BID_COMPLETED)
      bid.update_attributes!(status: BID_ACCEPTED)
    end

    # setup the parameters to update the bid control display (remove the buttons)
    @lang_id = bid.revision_language.language_id
    @bid_disp = bids_data_per_bid(bid, nil)
    @bid = bid

    @update_bid = true

    respond_to do |format|
      flash[:notice] = 'Project opened for editing'
      flash[:add_refresh_div] = true
      format.html
      format.xml
      format.js
    end

  end

  DUE_PAYMENT_BIDS = 0
  DUE_PAYMENT_TOTAL = 1
  DUE_PAYMENT_CURRENCY = 2
  DUE_PAYMENT_FROM_ACCOUNT = 3
  DUE_PAYMENT_HAS_ENOUGH = 4
  DUE_PAYMENT_HEADING = 5
  DUE_PAYMENT_SUBMIT_TEXT = 6
  DUE_PAYMENT_SUBMIT_CONFIRM = 7

  def accept_bid
    unless @user.verified?
      @warning = "You need to be verified in order to release projects to translators.\nClick on 'My account' and follow the link for verifying your identity."
      return
    end

    @bid = locate_bid(params[:bid_id])
    return false unless @bid

    bid_disp = bids_data_per_bid(@bid, nil)
    if (bid_disp[BID_INFO_ACTIONS_MASK] & BID_ACTION_ACCEPT_BID) == 0
      @warning = _('This bid cannot be accepted right now')
      return
    end

    @bid_total = @revision.cost_for_bid(@bid)
    account = @user.find_or_create_account(DEFAULT_CURRENCY_ID)

    if (@bid_total - account.balance) == 0.01
      logger.info 'Unable to accept bid because the client account is missing ' \
                  '$0.01. See iclsupp-1662.'
    end

    if account.balance >= @bid_total
      @heading = _('You have enough credit in your account to finance this work.')
      @button_text = _('Transfer funds to escrow and start work')
      @has_money_on_account = true
    else
      # create reminder...
      create_reminder_for_bid(@bid, @bid.revision.project.manager, EVENT_BID_WAITING_PAYMENT)
      begin
        @bid.wait_payment
      rescue ActiveRecord::RecordInvalid => invalid
        @warning = invalid.to_s
        return
      end
    end

    # remove new bid message
    Reminder.where(owner: @bid).first.try :delete

    @lang_id = @bid.revision_language.language_id
  end

  def transfer_bid_payment
    unless @user.can_pay?
      set_err("You don't have permission for that")
      return
    end

    begin
      accepted_conditions = make_dict(params[:accept])
    rescue
      accepted_conditions = []
    end

    if accepted_conditions.length != BID_ACCEPT_CONDITIONS.length
      @warning = _('You must accept all contract conditions in order to continue')
      return
    end

    bid = Bid.find(params[:bid_id])
    unless bid
      @warning = _('Bid not found')
      return
    end

    begin
      if @user.money_accounts.first.balance >= bid.total_cost
        bid.transaction do
          raise if bid.accepted?
          bid.transfer_escrow
          bid.accept
          if bid.try(:managed_work).try(:pending_payment?)
            bid.managed_work.activate
          end
        end
      else
        @warning = "seems that you don't have enough money anymore. Please refresh this page."
        return
      end
    rescue ActiveRecord::RecordInvalid => e
      @warning = 'This bid is not longer valid; this could happen if you update the volume of work. Please refuse bid and ask translator to offer a new one to continue.\n\nYou can find more information below:\n\n'
      @warning << bid.errors.full_messages.join('\n')
    rescue => e
      logger.error e.inspect
      logger.error e.backtrace.join("\n")
      @warning = _('Something wrong just happened. Please try again.')
    end
  end

  def finalize_bid
    @bid = locate_bid(params[:bid_id])
    return false unless @bid

    @bid_disp = bids_data_per_bid(@bid, nil)
    if (@bid_disp[BID_INFO_ACTIONS_MASK] & BID_ACTION_FINALIZE_WORK) == 0
      @warning = _('This bid cannot be finalized right now')
      return
    end

    unless @bid.account
      @bid.account = BidAccount.create(currency_id: DEFAULT_CURRENCY_ID, balance: 0)
    end

    # setup the parameters to update the bid control display (remove the buttons)
    @lang_id = @bid.revision_language.language_id
    @bid_disp = bids_data_per_bid(@bid, nil)
    @bid_disp[BID_INFO_ACTIONS_MASK] = 0 # clear the actions
    @with_review = @bid.revision_language.try(:managed_work).try(:waiting_for_payment?)
    @with_translation = @bid.status == BID_DECLARED_DONE
  end

  def finalize_bids
    begin
      accepted_conditions = make_dict(params[:accept])
    rescue
      accepted_conditions = []
    end

    if accepted_conditions.length != BID_FINALIZE_CONDITIONS.length
      @warning = 'You must accept all the above conditions to continue'
      return
    end

    bid = Bid.find(params[:bid_id])
    bid.finalize

    @chat.count_track

    existing_bookmark = @user.bookmarks.find_by(resource_type: 'User', resource_id: bid.translator.id)
    @translator_to_bookmark = bid.translator unless existing_bookmark
  end

  def review_complete
    @bid = locate_bid(params[:bid_id])

    unless @bid
      @warning = _('Requested bid not found.')
      return
    end

    # setup the parameters to update the bid control display (remove the buttons)
    @lang_id = @bid.revision_language.language_id
    @bid_disp = bids_data_per_bid(@bid, nil)
    if (@bid_disp[BID_INFO_ACTIONS_MASK] & BID_ACTION_COMPLETE_REVIEW) == 0
      @warning = _('This review cannot complete right now.')
      return
    end
    @bid_disp[BID_INFO_ACTIONS_MASK] = 0 # clear the actions

    @bid_message = ['Confirm that the review is complete', 'review_bids']

    respond_to do |format|
      format.js
      format.html
    end
  end

  def finalize_review
    begin
      accepted_conditions = make_dict(params[:accept])
    rescue
      accepted_conditions = []
    end

    if accepted_conditions.length != BID_REVIEW_CONDITIONS.length
      @warning = 'You must accept all the above conditions to continue'
      return
    end

    bid = Bid.where(id: params[:bid_id]).first

    unless bid
      if request.xhr?
        @warning = 'Requested bid not found.'
      else
        redirect_to action: :show
      end
      return false
    end

    if bid && bid.managed_work && bid.managed_work.complete?
      @warning = 'Cannot do that. The review was already finalized.'
      return
    end

    return unless bid.can_finalize_review?
    bid.finalize_review

    @chat.count_track

    flash[:notice] = 'Review is complete!'

    respond_to do |format|
      format.js
      format.html { redirect_to url_for(controller: :chats, action: :show, id: @chat.id, revision_id: @chat.revision.id, project_id: @chat.revision.project.id) }
    end
  end

  def cancel_review
    # This seems to be an admin only operation
    bid = locate_bid(params[:bid_id])
    return false unless bid

    # Should not be used with Website translation projects
    return false if bid&.revision_language&.revision&.cms_request_id.present?

    bid_disp = bids_data_per_bid(bid, nil)
    if (bid_disp[BID_ACTION_CANCEL_REVIEW] & BID_ACTION_CANCEL_REVIEW) == 0
      logger.info "----- bid.#{bid.id} review cannot canceled right now."
      @warning = _('This review cannot be canceled right now.')
      return
    end

    if bid.managed_work.can_cancel? || @user.has_supporter_privileges?
      bid.cancel_review
    else
      logger.info "------ PROBLEM! #{bid.revision_language.language.name} - review is not enabled. managed_work.active=#{managed_work.active}, managed_work.translation_status=#{managed_work.translation_status}"
      @warning = 'Something is wrong! This job is not being reviewed.'
      return
    end

  end

  def enable_review_from_table
    chat = Chat.find(params[:id])

    # Should not be used with Website translation projects
    return false if chat&.revision&.cms_request.present?

    managed_work = chat.revision.revision_language.managed_work
    managed_work.wait_for_payment
  end

  def enable_review
    @bid = locate_bid(params[:bid_id])
    @from_languages_table = params[:from_languages_table] == 1
    return false unless @bid

    # Should not be used with Website translation projects
    return false if @bid&.revision_language&.revision&.cms_request_id.present?

    bid_disp = bids_data_per_bid(@bid, nil)
    if (bid_disp[BID_INFO_ACTIONS_MASK] & BID_ACTION_ADD_REVIEW) == 0
      @warning = _('You cannot enable review right now')
      return
    end

    account = @user.find_or_create_account(DEFAULT_CURRENCY_ID)
    if account.balance >= @bid.reviewer_payment
      @has_money_on_account = true
    else
      @bid.managed_work.wait_for_payment
    end

    # setup the parameters to update the bid control display (remove the buttons)
    @lang_id = @bid.revision_language.language_id
    @bid_disp = bids_data_per_bid(@bid, nil)
    @bid_disp[BID_INFO_ACTIONS_MASK] = 0 # clear the actions
    @bid_message = ['Confirm acceptance of this bid', 'accept_bids']
  end

  def pay_for_review
    if @user.alias? && !@user.alias_profile.financial_pay
      set_err("You don't have permission for that")
    end

    managed_work = ManagedWork.find_by(id: params[:managed_work_id])
    bid = managed_work.try(:owner).try(:selected_bid)
    return raise "Can't find an object." unless managed_work && bid

    if @user.money_account.balance >= bid.reviewer_payment
      bid.transfer_review_escrow
      bid.start_review
    else
      set_err("You can't pay right now. Maybe you are out of money?")
    end
  end

  def show
    @bids = @chat.bids
    @bid_buttons = []
    @bids_disp = get_bids_disp
    session[:bids_to_accept] = nil
    session[:bids_to_review] = nil
    added_actions = 0
    @bids_disp.each do |bid|
      # logger.info("lang - #{bid[BID_INFO_LANG_NAME]}, actions - #{bid[BID_INFO_ACTIONS_MASK]}")
      bits_list(bid[BID_INFO_ACTIONS_MASK]).each do |action|
        # logger.info("checking action: #{action}")
        if (added_actions & action) == 0
          @bid_buttons << [BID_ACTION_NAMES[action], action]
          added_actions |= action
        end
      end
    end
    if @user == @project.client
      @header = "Communication with #{@chat.translator.full_name}"
      @otherparty = @chat.translator
    elsif @user == @chat.translator
      @header = "Communication with #{@chat.revision.project.client.full_name}"

      # translators also see the languages they were selected to work ok
      @chat_languages = @chat.chat_languages
      @otherparty = @project.client

      if @user.level == EXPERT_TRANSLATOR
        accepted_bids = @chat.bids.where(['bids.status IN (?)', BID_ACCEPTED_STATUSES])
        if accepted_bids.empty?
          rl_ids = @revision.revision_languages.where(['revision_languages.language_id IN (?)', @user.to_languages.collect(&:id)]).collect(&:id)
          unless rl_ids.empty?
            managed_works = ManagedWork.where(['(active = ?) AND (owner_type = (?)) AND (owner_id IN (?)) AND (translator_id IS NULL)', MANAGED_WORK_ACTIVE, 'RevisionLanguage', rl_ids])
            @can_review = !managed_works.empty?
          end
        end
      end

    elsif @is_reviewer
      @header = "Communication between #{@chat.revision.project.client.full_name} and #{@chat.translator.full_name}"
      review_rls = @chat.revision_languages.where(['revision_languages.id IN (?)', @user.managed_works.where(['(managed_works.owner_type=?) AND (managed_works.owner_id IN (?)) AND (managed_works.active=?)', 'RevisionLanguage', @revision.revision_languages.collect(&:id), MANAGED_WORK_ACTIVE]).collect(&:owner_id)])
      @chat_languages = review_rls.collect do |rl|
        [rl.language] + (rl.selected_bid ? [rl.selected_bid.status, rl.selected_bid.id] : [BID_TERMINATED, nil])
      end
    else
      @header = "Communication between #{@chat.revision.project.client.full_name} and #{@chat.translator.full_name}"
    end

    # posts are possible if this revision is still open to bids or if the translator has completed bids here
    @user_can_post = (@user.is_client? && @user.can_modify?(@project)) || (@chat.translator == @user) || @is_reviewer || @user.has_supporter_privileges?
    reviewers = []
    @chat.revision_languages.each do |rl|
      if rl.managed_work && (rl.managed_work.active == MANAGED_WORK_ACTIVE) && rl.managed_work.translator
        reviewers << rl.managed_work.translator
      end
    end

    manager = @project.alias || @project.client
    @for_who = collect_target_users(@user, [manager, @chat.translator] + reviewers, @chat.messages)

    @bid_currencies = Currency.names_map

    respond_to do |format|
      format.html
      format.xml
    end
  end

  def create_message
    @redirect_url = request.referer ? :back : nil
    if @orig_user
      flash[:notice] = "you can't post a message while logged in as other user"
      redirect_to :back
      return
    end
    warnings = []

    to_who = get_target_users

    if to_who.empty?
      warnings << _('You must select at least one target for this message')
    end

    warnings << _('No message entered') if params[:body].blank?

    if @user.userstatus == USER_STATUS_CLOSED
      warnings << _('Your account is closed')
    end

    if (@user[:type] == 'Translator') && @user.to_lang_ids.empty?
      warnings << _("You don't have any language approved")
    end

    if warnings.empty?
      begin
        message = create_message_in_chat(@chat, @user, to_who, params[:body], params)
      rescue ActiveRecord::RecordInvalid => e
        warnings << _('We was not able to save your message, if you are uploading an attachment please check filesize and try again. Reason: %s') % e.message
      else
        if message.errors.blank?
          flash[:ack] = _('Your message was sent!')
        else
          message.errors.full_messages.each { |x| warnings << x }
          flash[:notice] = list_errors(message.errors.full_messages)
        end
      end
    end

    if !warnings.empty?
      @warning = warnings.collect { |w| "- #{w}." }.join("\n")
    else
      flash[:ack] = _('Your message was sent!')
      @redirect_url = project_revision_chat_path(id: @chat.id, t: Time.now.to_i, anchor: 'reply')
    end

    respond_to do |f|
      f.html { @redirect_url.present? ? (redirect_to @redirect_url) : (render plain: 'ok') }
      f.js
    end
  end

  def check_invoice_status
    bid = locate_bid(params[:bid_id])
    # if there wasn't any bid, create one from scratch
    if bid && bid.account
      @invoices = []
      bid.account.credits.each { |credit| @invoices << credit.owner }
      @redirect_url = if @invoices.length == 1
                        url_for(controller: :finance, action: :invoice, id: @invoices[0].id)
                      else
                        url_for(controller: :finance, action: :invoices)
                      end
    end
  end

  def attachment
    begin
      attachment = Attachment.find(params[:attachment_id])
    rescue
      set_err('Cannot find attachment')
      return
    end
    if attachment.message.owner != @chat
      set_err("attachment doesn't belong to this ticket")
      return
    end
    send_file(attachment.full_filename)
  end

  private

  def verify_ownership
    res = do_verify_ownership(project_id: params[:project_id], revision_id: params[:revision_id], chat_id: params[:id])

    if res && (params[:action] == 'show') && @chat
      if @user[:type] == 'Translator'
        @edit_languages = @chat.revision_languages.collect(&:language)
        unless @edit_languages.empty?
          set_glossary_edit(@project.client, @revision.language, @edit_languages)
        end
      elsif @user == @project.client
        set_glossary_edit(@user, @revision.language, @revision.languages)
      end
    end

    res
  end

  def bids_data_per_bid(bid, alternative_language = nil)
    client_logged_in = if @user[:type] == 'Client'
                         true
                       else
                         UserSession.logged_in(@project.client_id)
                       end
    bid_data = if bid
                 [bid.revision_language.language, [bid]]
               else
                 [alternative_language, []]
               end
    bids_data_per_language(bid_data, client_logged_in)
  end

  # returns an easy to render structure for the bid
  def get_bids_disp
    client_logged_in = UserSession.logged_in(@project.client_id)
    res = @revision.bids(@chat.id).collect do |bid_data|
      bids_data_per_language(bid_data, client_logged_in)
    end
    res
  end

  def bids_data_per_language(bid_data, client_logged_in)
    entry = [bid_data[0]&.id, bid_data[0]&.name]

    is_website_translation_project = bid_data[1][0]&.revision_language&.revision&.cms_request_id.present?

    comment = ''
    possible_action = 0
    can_show = false
    can_edit = false
    can_arbitrate = false
    chat_id = nil
    completed = nil
    accept_time = nil
    expiration_time = nil

    revision_language = RevisionLanguage.includes(:selected_bid).where('revision_id = ? and language_id = ?', @revision.id, bid_data[0]&.id).first

    # check if the bid exists (must be an array with just one item)
    if bid_data[1].length >= 1
      bid = bid_data[1][0]
      can_arbitrate = bid.can_arbitrate
      comment = Bid::BID_STATUS[bid.status]
      chat_id = bid.chat_id
      accept_time = bid.accept_time
      expiration_time = bid.expiration_time
      entry << bid.id

      review_enabled = false
      review_disabled = false
      review_pending = false
      review_complete = false

      if revision_language.managed_work
        managed_work = revision_language.managed_work

        review_enabled = managed_work.active == MANAGED_WORK_ACTIVE
        review_disabled = managed_work.disabled?
        review_pending = review_enabled && managed_work.reviewing?
        review_waiting_for_payment = review_enabled && managed_work.waiting_for_payment?
        review_complete = review_enabled && managed_work.complete?

      end

      if @user[:type] == 'Translator'

        is_translator = (@chat.translator == @user)

        if (bid.status != BID_ACCEPTED) && (bid.status != BID_COMPLETED) && (bid.status != BID_REFUSED) && (bid.status != BID_DECLARED_DONE)
          if revision_language.selected_bid && (revision_language.selected_bid != bid)
            comment = _('Another bid has been accepted')
          elsif bid.status == BID_TERMINATED
            comment = _('This work has been terminated in an abritration process')
            can_show = is_translator
          elsif bid.status == BID_WAITING_FOR_PAYMENT
            comment = _('Bid for %s was accepted, but is in hold waiting for client funding. Please wait to start your work.') % bid.print_amount
            can_show = is_translator
            can_arbitrate = is_translator
          elsif client_logged_in && is_translator
            comment = _('Bid for %s given and cannot be changed right now') % bid.print_amount
          elsif bid.status == BID_GIVEN
            if is_translator
              comment = _('You bid %s') % bid.print_amount
              possible_action = BID_ACTION_EDIT_BID | BID_ACTION_DELETE_BID
            else
              comment = _('%s bid %s') % [@chat.translator.full_name, bid.print_amount]
            end
          end
        elsif bid.status == BID_ACCEPTED
          completed = revision_language.completed_percentage
          if is_translator
            comment = _('Your bid for %s was accepted') % bid.print_amount

            if @revision.cms_request && (completed == 100)
              possible_action = BID_ACTION_SELF_COMPLETE
            elsif (completed == 100) || (@revision.kind != TA_PROJECT)
              possible_action = BID_ACTION_DECLARE_DONE
            end
          else
            comment = _('Bid by %s was accepted. Waiting for translator to complete the work.') % @chat.translator.full_name
            if review_complete
              comment += '<br />' + _('Review is complete')
            elsif (@revision.kind != MANUAL_PROJECT) && (completed == 100) && review_pending
              possible_action = BID_ACTION_COMPLETE_REVIEW
            end
          end
          can_show = is_translator
        elsif bid.status == BID_DECLARED_DONE
          if is_translator
            comment = _('You declared the work as completed. The client has up to 7 days to revise it and release payment to you.')
          else
            comment = _('%s declared the work as done') % @chat.translator.full_name
            if review_complete
              comment += '<br />' + _('Review is complete')
            elsif review_pending
              # TODO: iclsupp-700 when is a bidding project with documents, the review button don't appear
              possible_action = BID_ACTION_COMPLETE_REVIEW
            end
          end
          can_show = is_translator
          completed = 100
        elsif bid.status == BID_COMPLETED
          if is_translator
            comment = _('Work has been completed for %s') % bid.print_amount
          else
            comment = _('Work by %s has been completed') % @chat.translator.full_name
            if review_complete
              comment += '<br />' + _('Review is complete')
            elsif review_pending
              possible_action = BID_ACTION_COMPLETE_REVIEW
            end
          end
          can_show = is_translator
        end
        entry += [bid.amount, (possible_action == 0)]
      elsif @user.has_admin_privileges? || @user.has_client_privileges?

        is_client = [@user, @user.master_account].include? @project.client
        is_admin = @user.has_admin_privileges?

        # user is client
        if bid.status == BID_COMPLETED
          comment = _('Work has been completed for %s.') % bid.print_amount
          if review_complete
            comment += '<br />' + _('This work has been reviewed by %s.') % managed_work.translator.full_name
          elsif review_pending
            comment += '<br />' + _('Translation is now being reviewed.')
          elsif review_waiting_for_payment
            comment += '<br />' + _('The review is also finished.')
            possible_action = if @revision.cms_request
                                0
                              else
                                BID_ACTION_FINALIZE_WORK
                              end
          end
          can_show = is_client
        elsif bid.status == BID_ACCEPTED
          comment = bid.accept_time ? _('Bid on %s was accepted on %s.') % [bid.print_amount, bid.accept_time.strftime(TIME_FORMAT_STRING)] : ''
          if review_enabled
            comment += if review_complete
                         '<br />' + _('The work has been completed and reviewed.')
                       elsif review_pending
                         '<br />' + _('Translation is now being reviewed.')
                       else
                         '<br />' + _('Translation is in progress. Review will be perfomed once translation is complete.')
                       end
          end
          can_show = is_client
          can_edit = @user.can_modify?(@revision.project)
          completed = revision_language.completed_percentage
        elsif bid.status == BID_DECLARED_DONE
          comment = _('The translator declared that the work is complete.')
          if review_enabled
            if review_complete
              comment += '<br />' + _('The work has been completed and reviewed.')
            elsif review_waiting_for_payment
              comment += '<br />' + _('The work has been completed and reviewed.')
              if is_client || is_admin
                possible_action = !@revision.cms_request ? BID_ACTION_FINALIZE_WORK : 0
              end
            elsif review_pending
              comment += '<br />' + _('Translation is now being reviewed.')
              possible_action = if is_admin && !is_website_translation_project
                                  BID_ACTION_CANCEL_REVIEW
                                else
                                  0
                                end
            else
              comment += '<br />' + _('Translation is complete. Waiting for reviewer.')
              possible_action = if is_admin && !is_website_translation_project
                                  BID_ACTION_CANCEL_REVIEW
                                else
                                  0
                                end
            end
          elsif is_client || is_admin
            comment += ' ' + _('You have up to 7 days to revise it and release payment to translator.')
            possible_action = !@revision.cms_request ? BID_ACTION_FINALIZE_WORK : 0
          end
          can_show = is_client || is_admin
          can_edit = @user.can_modify?(@revision.project)
          completed = 100
        elsif bid.status == BID_REFUSED
          comment = _('Bid for %s was refused') % bid.print_amount
          possible_action = BID_ACTION_DELETE_BID if is_client || is_admin
        elsif bid.status == BID_TERMINATED
          comment = _('Work on this bid has been terminated')
          possible_action = BID_ACTION_CANCEL_BID if is_client || is_admin
          can_show = is_client
        elsif bid.status == BID_WAITING_FOR_PAYMENT
          if is_client && bid.try(:account).try(:credits).try(:any?)
            possible_action = BID_ACTION_COMPLETE_PAYMENT
          end
          possible_action = BID_ACTION_REFUSE_BID
          can_show = is_client || is_admin
        elsif !revision_language.selected_bid.nil?
          comment = _('Another bid has been selected for this language.<br />Status: %s') % Bid::BID_STATUS[revision_language.selected_bid.status]
          possible_action = 0
        elsif bid.status == BID_GIVEN
          review_text = if managed_work && managed_work.enabled?
                          if @revision.cms_request
                            # Website Translation project
                            ', review cost: %s' % bid.print_amount(REVIEW_PRICE_PERCENTAGE)
                          else
                            # Other types of projects
                            ', review cost: %s' % bid.print_amount(0.5)
                          end
                        else
                          ''
                        end
          comment = _("Translator bid %s#{review_text}<br /><span class=\"comment\">%.2f %s total</span>") % [bid.print_amount, bid.revision_language.revision.cost_for_bid(bid).ceil_money, bid.currency.name]
          if (is_admin || is_client) && !(review_enabled && (revision_language.managed_work.translator == bid.chat.translator))
            possible_action = BID_ACTION_ACCEPT_BID | BID_ACTION_REFUSE_BID
            possible_action |= BID_ACTION_EDIT_BID if is_admin
          end
        else
          possible_action = 0
        end

        if is_client && review_disabled && BID_ASSIGNED_STATUS.include?(bid.status) &&
           @user.can_modify?(@project) && !is_website_translation_project
          possible_action |= BID_ACTION_ADD_REVIEW
        end

        entry += [bid.amount, true]
      else
        entry += [bid.amount, true]
      end
    else
      # there is no bid for this language
      entry << nil
      if @user[:type] == 'Translator'
        # 1) No bid accepted for this language
        # 2) The translator is qualified to translate to this language
        # also check if translator can bid on this specific revision and language
        if revision_language.selected_bid.nil? && (@user != revision_language.managed_work.try(:translator))
          if (@user.userstatus == USER_STATUS_PRIVATE_TRANSLATOR) || (@user.translator_language_tos.where(["(language_id=#{revision_language.language_id}) AND (status=#{TRANSLATOR_LANGUAGE_APPROVED})"]).first && @user != revision_language.try(:managed_work).try(:translator))
            comment = _('Open to bids')
            possible_action = BID_ACTION_MAKE_BID
            entry += ['', false]
          else
            comment = _('You are not qualified to translate to this language')
            entry += ['', true]
          end
        else
          comment = if @user == revision_language.managed_work.try(:translator)
                      _("You can't bid on this project because you are assigned as reviewer")
                    else
                      _('This revision is not open to bids')
                    end

          entry += ['', true]
        end
      else
        comment =
          if revision_language.selected_bid.nil?
            _('No bid given')
          else
            "Another bid has been selected for this language.<br />Status: #{Bid::BID_STATUS[revision_language.selected_bid.status]}"
          end
        entry += ['', true]
      end
    end
    bid_show_text = if can_edit
                      _('Extend completion date / resolve issues')
                    elsif can_arbitrate
                      _('Show bid info / resolve issues')
                    else
                      _('Show bid info')
                    end
    # logger.info "----------- can_edit: #{can_edit}, can_arbitrate: #{can_arbitrate}, can_show: #{can_show}"

    possible_action = 0 if @user.is_client? && !@user.can_modify?(@project)
    entry += [comment, possible_action, chat_id, can_show, bid_show_text, completed, accept_time, expiration_time]

    entry
  end

  def bits_list(val)
    res = []
    left = val
    i = 1
    while left != 0
      if (left & i) != 0
        res << i
        left &= ~i
      end
      i = i << 1
    end
    res
  end

  def locate_bid(id)
    begin
      bid = Bid.find(id)
    rescue
      return nil
    end

    if !bid.chat == @chat
      logger.info(" -------- Bid#{id} don't belong to chat #{@chat.id}")
      set_err('bid does not belong to chat')
      return nil
    end
    bid
  end

  # this check is made here and not in the DB because the created chat is still not associated
  # with a revision or user.
  def test_before_creation
    if @user[:type] != 'Translator'
      set_err('A translator needs to start the chat')
      return false
    end
    other_chat = @user.chats.where('revision_id=?', @revision.id).first
    if other_chat
      set_err('A chat already exists on this project')
      return false
    end
    if @project.not_last_revision?(@revision)
      set_err('New chats can only be created in the last revision of this project')
      return false
    end
    if (@revision.kind == TA_PROJECT) && (@user.userstatus != USER_STATUS_QUALIFIED)
      set_err('You must first do a practice project to do live projects')
      return false
    end
    true
  end

  # ================ reminders manipulation =====================

  def create_user_reminder_for_bid(bid)
    to_who = bid.chat.revision.project.manager
    event = EVENT_NEW_BID
    create_reminder_for_bid(bid, to_who, event)
  end

  def delete_user_reminder_for_bid(bid)
    to_who = bid.chat.revision.project.manager
    delete_reminder_for_bid(bid, to_who)
  end

  # ---------------------- auto track creation ----------------------------
  # add a track to the created chat under the selected revision and project for the current session of this user
  def add_track_to_users(chat)
    logger.info("----------- CHAT: adding track to chat #{chat.id}")
    track = ChatTrack.new(resource_id: chat.id)
    chat.add_track(track, @user_session)
    chat.revision.project.client.user_sessions.each do |user_session|
      track = ChatTrack.new(resource_id: chat.id)
      chat.add_track(track, user_session)
    end
  end

  def verify_modify
    unless @user.can_modify?(@project)
      set_err "You can't do that."
      nil
    end
  end
end
