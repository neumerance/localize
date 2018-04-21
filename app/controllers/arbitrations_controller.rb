class ArbitrationsController < ApplicationController
  include ::Reminders

  prepend_before_action :setup_user
  before_action :verify_supporter_privileges, only: [:assign_to_supporter, :pending, :edit_ruling, :supporter_index, :close, :reopen]
  before_action :verify_ownership, except: [:index, :pending, :supporter_index, :summary, :new, :request_cancel_bid, :create_cancel_bid_arbitration]
  before_action :create_reminders_list, only: [:show]
  layout :determine_layout
  before_action :setup_help

  def supporter_index
    @header = 'Arbitrations assigned to you'
    @open_arbitrations = @user.arbitrations.joins(:accepted_offer).where(['(arbitration_offers.id IS NULL) AND (arbitrations.status != ?)', ARBITRATION_CLOSED])
    @closed_arbitrations = @user.arbitrations.joins(:accepted_offer).where(['(arbitration_offers.id IS NOT NULL) OR (arbitrations.status = ?)', ARBITRATION_CLOSED])
  end

  def index
    @header = _('Your Arbitrations')

    @pager = ::Paginator.new(@user.claims_to_others.count + @user.claims_by_others.count, PER_PAGE) do |offset, per_page|
      @user.open_arbitrations("LIMIT #{offset},#{per_page}")
    end
    @arbitrations = @pager.page(params[:page])
    @list_of_pages = []
    for idx in 1..@pager.number_of_pages
      @list_of_pages << idx
    end
    @show_number_of_pages = (@pager.number_of_pages > 1)
  end

  def summary
    @header = _('Your Arbitrations - summary')
    @arbitrations = @user.open_arbitrations
  end

  def new
    kind = params[:kind]
    show = nil
    if kind == 'bid'
      begin
        @bid = Bid.find(Integer(params[:bid_id]))
        if do_verify_ownership(project_id: @bid.chat.revision.project_id,
                               revision_id: @bid.chat.revision_id,
                               chat_id: @bid.chat_id,
                               bid_id: @bid.id)
          @header = _('Request changes on bid')
          @requests = [[_('Cancel this bid'), url_for(action: 'request_cancel_bid')]]
          @sections = %w(Project Status Client Translator)
          @sections << 'Accepted on' if @bid.has_accepted_details
          @sections << 'Expires on' if @bid.has_expiration_details
          @sections << 'Bid amount'
          session[:bid_arbitration_request] = { bid_id: @bid.id }
          show = :new_bid_arbitration
        else
          return
        end
      rescue
      end
    end

    show = :cant_do unless show

    render action: show
  end

  def pending
    @new_arbitrations = Arbitration.where(["(type_code IN (#{[SUPPORTER_ARBITRATION_CANCEL_BID, SUPPORTER_ARBITRATION_WORK_MUST_COMPLETE].join(',')})) AND (status != #{ARBITRATION_CLOSED}) AND (supporter_id is NULL)"])
  end

  def request_cancel_bid
    @request_made = _('Cancel this bid')
    other_party = if @user[:type] == 'Client'
                    _('translator')
                  else
                    _('client')
                  end
    @how_to_handle_options = [[_('Work it out with %s') % other_party, 'self'],
                              [_('Ask the intervention of a support person'), 'supporter']]
  end

  def create_cancel_bid_arbitration
    warnings = []
    reason = params[:reason]
    how_to_handle = params[:how_to_handle]
    logger.info how_to_handle
    if !reason || (reason == '')
      warnings << _('You must explain why you want to cancel this bid.')
    end
    unless how_to_handle
      warnings << _('You must select how to handle this request.')
    end

    if warnings.empty?
      ok = false
      begin
        bid = Bid.find(session[:bid_arbitration_request][:bid_id])
        if how_to_handle == 'self'
          arb_type = MUTUAL_ARBITRATION_CANCEL_BID
          ok = true
        elsif how_to_handle == 'supporter'
          arb_type = SUPPORTER_ARBITRATION_CANCEL_BID
          ok = true
        end
      rescue
        bid = nil
      end

      if ok
        if @user[:type] == 'Client'
          initiator_id = bid.chat.revision.project.client_id
          against_id = bid.chat.translator_id
          against = bid.chat.translator
        else
          against_id = bid.chat.revision.project.client_id
          against = bid.chat.revision.project.client
          initiator_id = bid.chat.translator_id
        end

        if Arbitration.where(object: bid).any?
          @warning = 'An arbitration process for this bid already exists'
          return
        end

        @arbitration = Arbitration.new(type_code: arb_type,
                                       object_id: bid.id,
                                       object_type: 'Bid',
                                       initiator_id: initiator_id,
                                       against_id: against_id,
                                       status: ARBITRATION_CREATED)
        @arbitration.save!

        if against.can_receive_emails?
          ReminderMailer.arbitration_started(against, @user, @arbitration, arb_type).deliver_now
        end

        add_message_to_arbitration(reason)

        @redirect_url = arbitration_path(id: @arbitration.id)
      end
    else
      @warning = ''
      warnings.each { |warning| @warning = @warning + warning + "\n" }
    end
  end

  def show
    if (@arbitration.type_code == MUTUAL_ARBITRATION_CANCEL_BID) ||
       (@arbitration.type_code == SUPPORTER_ARBITRATION_CANCEL_BID)

      @header = _('Request to cancel translation work')
      if @arbitration.type_code == MUTUAL_ARBITRATION_CANCEL_BID
        @arbitration_explaination = 'This type of arbitration is created due to a request by either the client or translator. Either client and translator may make offers to end the work. The arbitration is conclude and the work finalized when the one of the parties accepts the offer made by another.'
        @content = 'bid_arbitration_content'
      else
        @arbitration_explaination = 'This type of arbitration is created when either the client or translator request the assistance of a support person. The support person will ask for clarifications and will make a ruling regarding the translator work.'
        @content = 'supporter_arbitration_content'
      end

      @can_post = @arbitration.status == ARBITRATION_CREATED

    elsif @arbitration.type_code == SUPPORTER_ARBITRATION_WORK_MUST_COMPLETE
      @header = _('Request to finalize translation work')
      @arbitration_explaination = 'This arbitration occures when a project deadline passes and the project is not finalized. '
      @arbitration_explaination += if @user[:type] == 'Client'
                                     "You must review the translator's work. If it is incomplete or fauly, the project may be canceled and all funds will be returned to you. Otherwise, the work must be accepted as complete."
                                   elsif @user[:type] == 'Translator'
                                     'You should have already completed the work by this time. The client will now review it and accept the project if it is complete and in satisfactory quality.'
                                   else
                                     'You need to assist the client in reviewing the translation work. If it is complete, the client must accept the work. Otherwise, you can make a ruling about full or partial payment.'
                                   end
      @content = 'supporter_arbitration_content'

      @can_post = @arbitration.status == ARBITRATION_CREATED
    else
      logger.info("Can't find code for arbitration #{@arbitration.id} with type: #{@arbitration.type_code}")
    end

    @ruling = @arbitration.accepted_offer

    if !@user.has_supporter_privileges?
      setup_your_offer
      setup_other_offer
    else
      @can_assign_to_me = (@arbitration.supporter != @user)
      @can_make_ruling = (@arbitration.supporter_id == @user.id)
    end
  end

  def create_message
    if @orig_user
      flash[:notice] = "you can't post a message while logged in as other user"
      redirect_to :back
      return
    end

    if @arbitration.status == ARBITRATION_CREATED
      message = add_message_to_arbitration(params[:body])
      unless message.errors.full_messages.blank?
        flash[:notice] = list_errors(message.errors.full_messages)
      end
    else
      flash[:notice] = _('This arbitration is closed. You cannot post new messages.')
    end
    redirect_to action: :show
  end

  def edit_offer
    if (@arbitration.type_code != MUTUAL_ARBITRATION_CANCEL_BID) || (@arbitration.status != ARBITRATION_CREATED)
      @warning = _('Cannot make or edit offers for this arbitration.')
      return
    end
    setup_your_offer
    req = params[:req]
    if req == 'show'
      unless @your_offer
        @your_offer = ArbitrationOffer.new(user_id: @user.id,
                                           arbitration_id: @arbitration.id,
                                           status: OFFER_GIVEN)
      end
      @edit_your_offer = true
    elsif req.nil? || (req == 'save')
      amount = Float(params[:your_offer][:amount])
      if amount < 0
        @warning = _('The minimal offer you can make is zero')
      elsif amount > @work_amount
        @warning = _("the maximal offer you can make is the bid's value: %s %s") % [@work_amount, @work_currency.name]
      else
        unless @your_offer
          @your_offer = ArbitrationOffer.new(user_id: @user.id,
                                             arbitration_id: @arbitration.id,
                                             status: OFFER_GIVEN)
        end
        @your_offer.amount = amount
        @your_offer.save!
        @can_edit = !UserSession.logged_in(@arbitration.other_party(@user.id))

        # create a reminder about this offer to the other party
        other_party = @arbitration.other_party(@user.id)
        create_user_reminder(other_party, EVENT_ARBITRATION_OFFER_MADE)
        if User.find(other_party).can_receive_emails?
          ReminderMailer.arbitration_offer(other_party, @user, @arbitration, amount).deliver_now
        end
      end
    elsif (req == 'del') && @your_offer
      @your_offer.destroy
      @your_offer = nil

      # delete the reminder about this offer from the other party
      Reminder.by_owner_and_normal_user(@arbitration.other_party(@user.id), [EVENT_ARBITRATION_OFFER_MADE]).destroy_all
    end
  end

  def edit_ruling
    if @arbitration.supporter_id != @user.id
      @warning = _('You must assume responsibility before ruling on this arbitration.')
      return
    end

    @ruling = @arbitration.arbitration_offers.where(user_id: @user.id).first

    req = params[:req]
    if req == 'show'
      unless @ruling
        @ruling = ArbitrationOffer.new(user_id: @user.id,
                                       arbitration_id: @arbitration.id,
                                       status: OFFER_GIVEN)
      end
      @edit_ruling = true
    elsif req.nil? || (req == 'save')
      begin
        amount = Float(params[:ruling][:amount])
      rescue
        amount = nil
      end

      if amount.nil? || (amount < 0) || (amount > @work_amount)
        @warning = _("The ruling you can make is between zero and the bid's value: %s %s") % [@work_amount, @work_currency.name]
      else
        unless @ruling
          @ruling = ArbitrationOffer.new(user_id: @user.id,
                                         arbitration_id: @arbitration.id,
                                         status: OFFER_GIVEN)
        end
        @ruling.amount = amount
        @ruling.status = OFFER_ACCEPTED
        close_abritration(@ruling)
        @ruling.save!
      end
    end
  end

  def close
    close_abritration(nil, false)
    flash[:notice] = _('This arbitration has been closed')
    redirect_to action: :show
  end

  def accept_offer
    if (@arbitration.type_code != MUTUAL_ARBITRATION_CANCEL_BID) || (@arbitration.status != ARBITRATION_CREATED)
      @warning = _('Cannot make or edit offers for this arbitration.')
      return
    end
    setup_other_offer
    close_abritration(@other_offer)
    @other_offer.status = OFFER_ACCEPTED
    @other_offer.save!
  end

  def ask_for_supporter
    if (@arbitration.type_code != MUTUAL_ARBITRATION_CANCEL_BID) || (@arbitration.status != ARBITRATION_CREATED)
      @warning = _('Cannot modify the type of this arbitration.')
      return
    end
    @arbitration.arbitration_offers.destroy_all
    @arbitration.type_code = SUPPORTER_ARBITRATION_CANCEL_BID
    @arbitration.save!
  end

  def assign_to_supporter
    if @arbitration.supporter
      @warning = _('This arbitration is already assigned to a supporter.')
    else
      @arbitration.supporter = @user
      @arbitration.save!
    end
  end

  def reopen
    @arbitration.status = ARBITRATION_CREATED
    @arbitration.supporter_id = nil
    @arbitration.save!
    flash[:notice] = 'Arbitration open again!'
    redirect_to :back
  end

  def searcher
    @arbitrations = Kaminari.paginate_array(@user.open_arbitrations("LIMIT #{PER_PAGE_SUMMARY}")).page(params[:page]).per(params[:per_page])
    @your_arbitrations_message = if @arbitrations.length
                                   _('Recent %d of %d arbitrations') % [PER_PAGE_SUMMARY, @arbitrations.count] +
                                     "&nbsp;&nbsp;&nbsp;<a href=\"#{url_for(controller: :arbitrations, action: :index)}\">" + _('Older arbitrations') + '</a>' \
                                     "&nbsp;&nbsp;&nbsp;<a href=\"#{url_for(controller: :arbitrations, action: :summary)}\">" + _('Summary of all arbitrations') + '</a>'
                                 else
                                   _('Showing all your arbitrations')
                                 end
    respond_to do |format|
      format.js
    end
  end

  private

  def verify_supporter_privileges
    unless @user.has_supporter_privileges?
      set_err(_('You are not allowed to do this.'))
      false
    end
  end

  def verify_ownership
    # try to locate this arbitration
    begin
      @arbitration = Arbitration.find(params[:id])
    rescue
      logger.info "-------------- can't find arbitration #{params[:id]}"
      set_err(_('Cannot locate this arbitration'))
      return false
    end

    @work_amount = @arbitration.object.chat.revision.cost_for_bid(@arbitration.object)
    @work_currency = @arbitration.object.currency
    @accepted_offer = @arbitration.accepted_offer

    @work_balance = @arbitration.object.account.balance

    # supporters can see all arbitrations. Users can see their
    if @user.has_supporter_privileges?
      return true
    else
      return (@user.id == @arbitration.initiator_id) || (@user.id == @arbitration.against_id)
    end

  end

  def add_message_to_arbitration(body)
    message = Message.new(body: body, chgtime: Time.now)
    message.user = @user
    message.owner = @arbitration
    if message.valid?
      message.save!

      # see who needs to get this reminder
      # delete previous message reminders for this arbitration to the current user
      Reminder.by_owner_and_normal_user(@user.id, [EVENT_ARBITRATION_RESPONSE_NEEDED, EVENT_ARBITRATION_RESPONSE_REQUIRED]).destroy_all
      if (@user[:type] == 'Client') || (@user[:type] == 'Translator')
        to_who_list = [@arbitration.other_party(@user.id)]
        to_who_list << @arbitration.supporter_id if @arbitration.supporter
        to_who_list.each do |to_who|
          create_user_reminder(to_who, EVENT_ARBITRATION_RESPONSE_NEEDED)
          ReminderMailer.new_message_in_arbitration(to_who, @user, @arbitration, body, nil).deliver_now
        end
      else
        [@arbitration.against_id, @arbitration.initiator_id].each do |to_who|
          # delete all old reminders from both parties
          Reminder.by_owner_and_normal_user(to_who, [EVENT_ARBITRATION_RESPONSE_NEEDED, EVENT_ARBITRATION_RESPONSE_REQUIRED]).destroy_all
          # when an arbitrator posts, both parties must respond in a timely manner
          response_deadline = Time.now + Arbitration::TIME_TO_RESPOND_TO_ARBITRATION * DAY_IN_SECONDS
          create_user_reminder(to_who, EVENT_ARBITRATION_RESPONSE_REQUIRED, response_deadline)
          if User.find(to_who).can_receive_emails?
            ReminderMailer.new_message_in_arbitration(to_who, @user, @arbitration, body, response_deadline).deliver_now
          end
        end
      end
    end
    message
  end

  def close_abritration(offer, make_payment = true)
    # now, handle the money transfer and issues regarding this arbitration
    if make_payment && [MUTUAL_ARBITRATION_CANCEL_BID, SUPPORTER_ARBITRATION_CANCEL_BID, SUPPORTER_ARBITRATION_WORK_MUST_COMPLETE].include?(@arbitration.type_code)
      bid = @arbitration.object
      bid.status = BID_TERMINATED
      bid.save!

      client = bid.chat.revision.project.client
      translator = bid.chat.translator

      # make the partial payment to the translator
      to_account = translator.find_or_create_account(bid.currency_id)
      MoneyTransactionProcessor.transfer_money(bid.account, to_account, offer.amount, @work_currency, TRANSFER_PAYMENT_FROM_BID_ESCROW, FEE_RATE, client.affiliate)

      # return the rest to the client
      to_account = client.find_or_create_account(bid.currency_id)
      MoneyTransactionProcessor.transfer_money(bid.account, to_account, bid.account.balance, @work_currency, TRANSFER_REFUND_FROM_BID_ESCROW)

      # change review status to waiting for payment, since the escrow for review was returned
      # to the client account along with the remaining payment for the translator
      if bid.revision_language.managed_work.active?
        bid.revision_language.managed_work.wait_for_payment
      end

      # check if this is a part of a CMS project
      cms_request = bid.chat.revision.cms_request
      if cms_request
        cms_target_language = cms_request.cms_target_languages.where(language_id: bid.revision_language.language_id).first
        if cms_target_language
          cms_target_language.update_attributes!(status: CMS_TARGET_LANGUAGE_CREATED, translator_id: nil)
        end
        cms_request.update_attributes!(status: CMS_REQUEST_RELEASED_TO_TRANSLATORS)
        # Must reset the bid status because CmsRequestsController#reuses it.
        # otherwise the next translator that takes this translation job
        # (CmsRequest) will not be able to accept the bid, complete the job and get paid.
        bid.update!(status: BID_GIVEN)
      end

      # make sure we delete any pending invoice for this bid
      invoice_to_delete = nil
      bid.account.credits.each do |money_transaction|
        if (money_transaction.status == TRANSFER_PENDING) && (money_transaction.owner.class == Invoice)
          invoice_to_delete = money_transaction.owner
        end
      end
      invoice_to_delete.destroy if invoice_to_delete
    end

    @arbitration.status = ARBITRATION_CLOSED
    @arbitration.save!

    # clear any pending reminders
    Reminder.by_owner(@arbitration.initiator_id).destroy_all
    Reminder.by_owner(@arbitration.against_id).destroy_all
    Reminder.by_owner(@arbitration.supporter_id).destroy_all if @arbitration.supporter

    delete_all_reminders_for_bid_and_chat(@arbitration.object, @arbitration.object.chat)

    if make_payment
      # create close reminders to those how didn't make the offer
      to_who_list = if @arbitration.type_code == MUTUAL_ARBITRATION_CANCEL_BID
                      [@arbitration.other_party(@user.id)]
                    else
                      [@arbitration.initiator_id, @arbitration.against_id]
                    end
      to_who_list.each do |to_who|
        create_user_reminder(to_who, EVENT_ARBITRATION_CLOSED)
        if User.find(to_who).can_receive_emails?
          ReminderMailer.arbitration_closed(to_who, @arbitration, offer.amount).deliver_now
        end
      end
    end
  end

  def setup_your_offer
    @your_offer = ArbitrationOffer.where(user_id: @user.id, arbitration_id: @arbitration.id).first
    if @your_offer
      logger.info "Checking if can edit. @user.id: #{@user.id}, @arbitration.other_party(@user.id): #{@arbitration.other_party(@user.id)}"
      @can_edit = !UserSession.logged_in(@arbitration.other_party(@user.id)) && (@arbitration.status == ARBITRATION_CREATED)
    end
  end

  def setup_other_offer
    @other_offer = ArbitrationOffer.where(user_id: @arbitration.other_party(@user.id), arbitration_id: @arbitration.id).first
    if @other_offer
      @can_accept = (@other_offer.status == OFFER_GIVEN) && (@arbitration.status == ARBITRATION_CREATED)
    end
  end

  # ---------------------- message reminders ---------------------------
  def create_user_reminder(to_who, event, expiration_time = nil)
    reminder = Reminder.where(owner_id: @arbitration.id, owner_type: 'Arbitration', normal_user_id: to_who, event: event).first
    unless reminder
      reminder = Reminder.new(event: event,
                              expiration: expiration_time,
                              normal_user_id: to_who)
      reminder.owner = @arbitration
      reminder.save!
    end
  end

  def delete_user_reminders(to_who, events = nil)
    if events
      Reminder.where("(owner_type='Arbitration') AND (owner_id=#{@arbitration.id}) AND (normal_user_id=#{to_who}) AND (event IN (#{events.join(',')}))").delete_all
    else
      Reminder.where("(owner_type='Arbitration') AND (owner_id=#{@arbitration.id}) AND (normal_user_id=#{to_who})").delete_all
    end
  end

end
