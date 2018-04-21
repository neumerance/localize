class WebsiteTranslationContractsController < ApplicationController
  include ::TargetUsers

  prepend_before_action :setup_user
  before_action :locate_parents, except: [:send_broadcast]
  before_action :verify_qualified_translator, only: [:create]
  before_action :locate_contract, only: [:show, :create_message, :attachment, :update_application_status]
  before_action :setup_help
  before_action :forbid_for_autoassign_language_pairs, only: [:new, :create, :update_application_status]
  before_action :verify_view, only: [:show, :create_message, :attachment, :update_application_status]
  before_action :verify_modify, only: [:create_message, :update_application_status]
  layout :determine_layout

  def index; end

  def new
    @header = _('Apply for recurring translation work')
    @can_apply = @website.project_kind != TEST_CMS_WEBSITE && verify_qualified_translator
    @website_translation_contract = WebsiteTranslationContract.new
    contract = @website_translation_offer.website_translation_contracts.where('translator_id=?', @user.id).first
    if contract
      redirect_to controller: :website_translation_contracts, action: :show, website_id: @website.id, website_translation_offer_id: @website_translation_offer.id, id: contract.id
    end
  end

  def create

    unless @website_translation_offer.translator_can_apply(@user)
      flash[:notice] = 'You are the reviewer for this project. Cannot apply as translator.'
      redirect_to controller: :translator
      return
    end

    @message = params[:message]
    @apply = params[:apply]

    @website_translation_contract = WebsiteTranslationContract.new(params[:website_translation_contract])
    @website_translation_contract.status = (@apply == '1' ? TRANSLATION_CONTRACT_REQUESTED : TRANSLATION_CONTRACT_NOT_REQUESTED)
    @website_translation_contract.translator = @user
    @website_translation_contract.website_translation_offer = @website_translation_offer
    @website_translation_contract.currency_id = DEFAULT_CURRENCY_ID

    err = false

    if @message.blank?
      @website_translation_contract.errors.add(:base, _('You must enter a message to the client in order to apply for this work'))
      err = true
    end

    if @apply.blank?
      @website_translation_contract.errors.add(:base, _('Please indicate if you are applying to this job or not'))
      err = true
    end

    if @website_translation_contract.status == TRANSLATION_CONTRACT_REQUESTED
      if !@website_translation_contract.amount || (@website_translation_contract.amount == 0)
        @website_translation_contract.errors.add(:base, _('Please enter your per-word rate'))
        err = true
      elsif @website_translation_contract.amount < @website.client.minimum_bid_amount
        @website_translation_contract.errors.add(:base, _('The minimum per-word amount in the system is %.2f USD / word') % @website.client.minimum_bid_amount)
        err = true
      end
    end

    if err
      @header = _('Apply for recurring translation work')
      @can_apply = @website.project_kind != TEST_CMS_WEBSITE && verify_qualified_translator
      render action: :new
      return
    end

    @website_translation_contract.save!

    # if the translator is applying, add the rate to the initial message
    msg_to_client = @message
    if @website_translation_contract.status == TRANSLATION_CONTRACT_REQUESTED
      set_user_locale(@website.client)
      msg_to_client = _('I am applying to do this work at a rate of %.2f USD per word.') % @website_translation_contract.amount + "\n\n" + msg_to_client
      restore_locale
    end

    message = Message.new(body: msg_to_client, chgtime: Time.now)
    message.user = @user
    message.owner = @website_translation_contract
    message.save!

    message_delivery = MessageDelivery.new
    message_delivery.user = @website.client
    message_delivery.message = message
    message_delivery.save

    if @website.interview_translators == CLIENT_INTERVIEWS_TRANSLATORS
      if @apply == '1'
        @website.client.create_reminder(EVENT_NEW_WEBSITE_TRANSLATION_CONTRACT, @website_translation_contract)
        if @website.client.can_receive_emails?
          ReminderMailer.new_application_for_cms_translation(@website.client, @website_translation_contract, @message).deliver_now
        end
      else
        @website.client.create_reminder(EVENT_NEW_WEBSITE_TRANSLATION_MESSAGE, @website_translation_contract)
        if @website.client.can_receive_emails?
          ReminderMailer.new_message_for_cms_translation(@website.client, @website_translation_contract, message).deliver_now
        end
      end
    end

    redirect_to action: :show, id: @website_translation_contract.id

  end

  def create_message
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

    if (@user[:type] == 'Translator') && @user.to_lang_ids.empty? && !@user.private_translator?
      warnings << _("You don't have any language approved")
    end

    if warnings.empty?
      message = @website_translation_contract.add_message(@user, to_who, params)
      unless message.errors.full_messages.blank?
        message.errors.full_messages.each { |x| warnings << x }
        flash[:notice] = list_errors(message.errors.full_messages)
      else
        flash[:ack] = _('Your message was sent!')
      end
    end

    @warning = warnings.collect { |w| "- #{w}." }.join("\n") unless warnings.empty?

    respond_to do |format|
      format.js
      format.html { request.referer ? (redirect_to :back) : (render plain: '') }
    end
  end

  def send_broadcast
    @website = Website.find(params[:website_id])
    unless ([@user, @user.master_account].include? @website.client) || @user.has_supporter_privileges? # https://git.onthegosystems.com/icanlocalize/icanlocalize/commit/5c9b2d63c7e3d2479b7d5c90c3405e80d9a5e70d
      flash[:notice] = _('Operation not allowed')
      redirect_to(:back) && return
    end

    if params[:body].blank?
      flash[:notice] = _('No message entered')
    else
      accepted_contracts = @website.website_translation_contracts.find_all { |contract| contract.status == TRANSLATION_CONTRACT_ACCEPTED }
      accepted_contracts.each do |contract|
        to_who = [contract.translator]
        offer = contract.website_translation_offer
        if offer.managed_work && offer.managed_work.enabled? && offer.managed_work.translator
          to_who << offer.managed_work.translator
        end
        contract.add_message(@user, to_who, params)
      end
      flash[:notice] = _('Your messages were sent!')
    end

    redirect_to :back, notice: 'success!'
  end

  def show
    @header = 'Application for Website Translation work'
    @status_actions = []
    if @user.has_supporter_privileges? || @user.has_client_privileges?
      if @website_translation_contract.status == TRANSLATION_CONTRACT_NOT_REQUESTED
        @status_text = _('%s did not yet apply for this work.') % @website_translation_contract.translator.full_name
        @status_actions = []
      elsif @website_translation_contract.status == TRANSLATION_CONTRACT_REQUESTED
        @status_text = _('%s is interested in translating this project from <b>%s</b> to <b>%s</b>.') % [@website_translation_contract.translator.full_name, @website_translation_offer.from_language.nname, @website_translation_offer.to_language.nname]
        @status_actions << [_('Accept this application'), TRANSLATION_CONTRACT_ACCEPTED] if @website_translation_offer.translator_can_apply(@website_translation_contract.translator)
        @status_actions << [_('Decline this application'), TRANSLATION_CONTRACT_DECLINED]
      elsif @website_translation_contract.status == TRANSLATION_CONTRACT_ACCEPTED
        who_accepted = %w(Client Alias).include?(@user.type) ? 'You have' : 'The client has'
        @status_text = _("#{who_accepted} accepted %s's application for doing this translation work.") % @website_translation_contract.translator.full_name
        @status_actions = [[_('Cancel the application acceptance'), TRANSLATION_CONTRACT_DECLINED]]
      elsif @website_translation_contract.status == TRANSLATION_CONTRACT_DECLINED
        @status_text = _("You have declined %s's application for doing this translation work.") % @website_translation_contract.translator.full_name
        @status_actions << [_('Accept this application'), TRANSLATION_CONTRACT_ACCEPTED] if @website_translation_offer.translator_can_apply(@website_translation_contract.translator)
        @status_actions << [_('Allow this translator to be a reviewer'), TRANSLATION_CONTRACT_REQUESTED]
      end
    elsif @user[:type] == 'Translator'
      if @website_translation_offer.managed_work && (@website_translation_offer.managed_work.active == MANAGED_WORK_ACTIVE) && @website_translation_offer.managed_work.translator == @user
        @status_text = _('You are the reviewer for this project.')
        @status_actions = []
      else
        if @website_translation_contract.status == TRANSLATION_CONTRACT_NOT_REQUESTED
          @status_text = _('You did not yet apply for this work.')
          @status_actions = []
        elsif @website_translation_contract.status == TRANSLATION_CONTRACT_REQUESTED
          @status_text = _('You have applied for this work. The client did not make a decision yet.')
          @status_actions = [[_('Retract application'), TRANSLATION_CONTRACT_NOT_REQUESTED]]
        elsif @website_translation_contract.status == TRANSLATION_CONTRACT_ACCEPTED
          @status_text = _('Your application for doing this work has been accepted.')
          @status_actions = [[_('Retract application'), TRANSLATION_CONTRACT_NOT_REQUESTED]]
        elsif @website_translation_contract.status == TRANSLATION_CONTRACT_DECLINED
          @status_text = _('Your application for doing this work has been declined.')
          @status_actions = []
        end
      end
    end

    # If the associated WebsiteTranslationOffer is set to automatic translator
    # assignment, this page should only be used for chat. It should not have
    # any "action" buttons to allow translators applying/resigning, clients
    # accepting translators, etc.
    @status_actions = [] if @website_translation_offer.automatic_translator_assignment

    @website_translation_contract.new_messages(@user).each { |m| m.update_attributes(is_new: 0) }
    users = [@website_translation_offer.website.client, @website_translation_contract.translator]
    if @website_translation_offer.managed_work && (@website_translation_offer.managed_work.active == MANAGED_WORK_ACTIVE) && @website_translation_offer.managed_work.translator
      users << @website_translation_offer.managed_work.translator
    end
    @for_who = collect_target_users(@user, users, @website_translation_contract.messages)
    contracts = @website_translation_offer.website_translation_contracts.where(status: TRANSLATION_CONTRACT_ACCEPTED)
    @minimum_bid_amount = contracts.minimum(:amount)
    @maximum_bid_amount = contracts.maximum(:amount)
  end

  def attachment
    begin
      attachment = Attachment.find(params[:attachment_id])
    rescue
      set_err('Cannot find attachment')
      return
    end
    if attachment.message.owner != @website_translation_contract
      set_err("attachment doesn't belong to this translation offer")
      return
    end
    send_file(attachment.full_filename)
  end

  def update_application_status
    status = params[:status].to_i
    update_status = !params[:status].blank?

    return_to_src = params[:return_to_src].to_i == 1

    if (@user == @website_translation_contract.translator) &&
       [TRANSLATION_CONTRACT_NOT_REQUESTED, TRANSLATION_CONTRACT_REQUESTED, TRANSLATION_CONTRACT_DECLINED].include?(@website_translation_contract.status) &&
       (params[:website_translation_contract] && params[:website_translation_contract][:amount])

      amount = params[:website_translation_contract][:amount].to_f

      if amount < @website.client.minimum_bid_amount && !@user.private_translator?
        flash[:notice] = _('The minimum per-word amount in the system is %.2f USD / word') % @website.client.minimum_bid_amount
        redirect_to action: :show
        return
      end

      if (@website_translation_contract.status == TRANSLATION_CONTRACT_NOT_REQUESTED) || (@website_translation_contract.amount != amount)
        @website_translation_contract.amount = amount
        set_user_locale(@website.client)
        @message_to_send = if @website_translation_contract.status == TRANSLATION_CONTRACT_NOT_REQUESTED
                             _('I am applying to do this work at a rate of %.2f USD per word.') % @website_translation_contract.amount
                           else
                             _('I changed my bid to %.2f USD per word.') % @website_translation_contract.amount
                           end
        restore_locale
      end
    end

    prev_status = @website_translation_contract.status
    @website_translation_contract.status = status if update_status

    if @website_translation_contract.save
      if update_status
        Reminder.by_owner_and_normal_user(@website_translation_contract, @user).destroy_all
        if (@user == @website_translation_contract.translator) && (status == TRANSLATION_CONTRACT_REQUESTED)
          @website.client.create_reminder(EVENT_NEW_WEBSITE_TRANSLATION_CONTRACT, @website_translation_contract)
        elsif (@user == @website_translation_contract.translator) && (status == TRANSLATION_CONTRACT_NOT_REQUESTED)
          set_user_locale(@website.client)
          @message_to_send = if prev_status == TRANSLATION_CONTRACT_ACCEPTED
                               _('I am withdrawing my application from this project and will not be able to do any further work on it. I advice to open this job to other applications.')
                             else
                               _('I am withdrawing my application.')
                             end
          restore_locale
        elsif @user.has_client_privileges? || ([@user, @user.master_account].include? @website.client)
          if status == TRANSLATION_CONTRACT_ACCEPTED
            application_accepted = true
            @message_to_send = _('I accepted your application for this project.')
            @quiet_message = true
            if @website_translation_contract.translator.can_receive_emails?
              ReminderMailer.accepted_application_for_cms_translation(@website_translation_contract.translator, @website_translation_contract).deliver_now
            end
            if @website.interview_translators != 1
              still_open_pairs = @website.website_translation_offers.where('NOT EXISTS (SELECT * FROM website_translation_contracts WHERE ((website_translation_contracts.website_translation_offer_id=website_translation_offers.id) AND (website_translation_contracts.status=?)))', TRANSLATION_CONTRACT_ACCEPTED)
              if @website.client.can_receive_emails?
                ReminderMailer.assigned_translator(@website.client, @website_translation_contract, @website_translation_contract.translator, still_open_pairs).deliver_now
              end
            end
            # close this offer
            @website_translation_offer.update_attributes!(status: TRANSLATION_OFFER_CLOSED)
          elsif status == TRANSLATION_CONTRACT_DECLINED
            @message_to_send = _('I am declining your application for this project.')
            @website_translation_offer.update_attributes!(status: TRANSLATION_OFFER_OPEN)
            @website_translation_contract.translator.release_cms_jobs(@website, @website_translation_offer.to_language)
          elsif status == TRANSLATION_CONTRACT_REQUESTED
            @message_to_send = _('You can now apply again as a reviewer.')
            @website_translation_contract.translator.release_cms_jobs(@website, @website_translation_offer.to_language)
          end
        end
      end
      flash[:notice] = _('Application updated.')
      if application_accepted
        flash[:notice] += _(' If for some reason, the translator you choose does not answer you, please open a support ticket and we will assist you right away.')
      end
    else
      flash[:notice] = _('Application could not be updated')
    end

    if @message_to_send
      message = Message.new(body: @message_to_send, chgtime: Time.now)
      message.user = @user
      message.owner = @website_translation_contract
      message.save!

      other_side = @user == @website_translation_contract.translator ? @website.client : @website_translation_contract.translator

      if !@quiet_message && other_side.can_receive_emails?
        ReminderMailer.new_message_for_cms_translation(other_side, @website_translation_contract, message).deliver_now
      end

      message_delivery = MessageDelivery.new
      message_delivery.user = other_side
      message_delivery.message = message
      message_delivery.save

      if (@user.has_supporter_privileges? || (@user == @website.client)) && (status == TRANSLATION_CONTRACT_ACCEPTED)
        client_name = @website.client.full_name
        translator_name = @website_translation_contract.translator.full_name

        # Message for clients that selected the "ICL v2" translation service in
        # WPML. This "translation service" is also available for older WPML
        # versions, but is enforced in WPML >= 3.9. With ICL v2, there is no
        # way to choose a translator in WPML, only in ICL.
        icl_v2_message = <<~MSG
          Hello #{client_name} and #{translator_name},

          #{client_name}, we received the content for translation and translators have been assigned.

          To start the translations, click the "Pay and begin translation" button on the "Pending translation jobs" page at #{wpml_website_translation_jobs_url(@website)}

          If you have enough balance in your ICanLocalize account, the payment will be deducted from that balance after clicking the button. If the balance is not sufficient, you will be given several options to complete the payment.

          Once the translations are complete, they will be sent automatically to WPML ready to be published on your website.

          If you need any help, please do not hesitate to open a support ticket at https://www.icanlocalize.com/support/new.
        MSG

        # Message for clients that selected the "ICL v1" (legacy) translation
        # service in WPML (only possible in WPML <3.9). With ICL v1, the
        # client must choose a translator in WPML before sending contents to ICL.
        icl_v1_message = <<~MSG
          Hello #{client_name} and #{translator_name},

          I want to join the conversation and explain how to proceed.

          #{client_name}, to send content for translation you need to go to WordPress -> "WPML" -> "Translation Management" -> "Translation Dashboard" to select pages, posts or products.

          1. Select the checkboxes of the items you want to translate.
          2. Scroll down to the "Translation options" section, then choose the "Translate" option for the desired language.
          3. Click the "Add selected content to Translation Basket" button.
          4. Now, click on the blinking "Translation Basket" tab.
          5. In the "Translation Basket", you can review the items to send for translation and the languages.
          6. Make sure to select the option "#{translator_name} (ICanLocalize)" in the "Translate by" drop-down menu.
          7. Click on the "Send all items for translation" button.

          After sending the content for translation, you can click on the "Translation Jobs" link to view the WPML tab with the list of jobs. Just click on a batch name in the "Translation Jobs" tab to be redirected to ICanLocalize, and click on the "Set up pending translation jobs" button to see a summary of the content sent.

          To start the translations, click the "Pay and begin translation" button on the "Pending translation jobs" page at #{wpml_website_translation_jobs_url(@website)}

          If you have enough balance in your ICanLocalize account, the payment will be deducted from that balance after clicking the button. If the balance is not sufficient, you will be given several options to complete the payment.

          Once the translations are completed, WPML can download them automatically on your website.

          If you need any help, please do not hesitate to open a support ticket at https://www.icanlocalize.com/support/new.
        MSG

        supporter = User.where('email=?', CMS_SUPPORTER_EMAIL).first

        message_to_send = @website.icl_v2_translation_service? ? icl_v2_message : icl_v1_message
        message = Message.new(body: message_to_send, chgtime: Time.now)
        message.user = supporter
        message.owner = @website_translation_contract
        message.save!

        [@website.client, @website_translation_contract.translator].each do |to_who|
          if to_who.can_receive_emails?
            ReminderMailer.new_message_for_cms_translation(to_who, @website_translation_contract, message).deliver_now
          end

          message_delivery = MessageDelivery.new
          message_delivery.user = to_who
          message_delivery.message = message
          message_delivery.save
        end
      end
    end

    if return_to_src
      redirect_to(request.referer)
    else
      redirect_to action: :show
    end
  end

  private

  def locate_parents
    begin
      @website_translation_offer = WebsiteTranslationOffer.find(params[:website_translation_offer_id])
    rescue
      set_err("Can't find this translation offer")
      return false
    end
    @website = @website_translation_offer.website
    if @website.id != params[:website_id].to_i
      set_err('Website mismatch')
      return false
    end
    if (@user[:type] == 'Client') && (@website.client != @user)
      set_err("Website doesn't belong to you")
      return false
    end
  end

  def locate_contract
    begin
      @website_translation_contract = WebsiteTranslationContract.find(params[:id].to_i)
    rescue
      set_err("Can't locate contract")
      return false
    end

    if @website_translation_contract.website_translation_offer != @website_translation_offer
      set_err("Contract doesn't belog to offer")
      return false
    end
  end

  def verify_qualified_translator
    (@user[:type] == 'Translator') && [USER_STATUS_QUALIFIED, USER_STATUS_PRIVATE_TRANSLATOR].include?(@user.userstatus)
  end

  def verify_view
    unless @user.can_view?(@website_translation_contract)
      set_err("You can't do that.")
      false
    end
  end

  def verify_modify
    unless @user.can_modify?(@website_translation_contract)
      set_err("You can't do that.")
      false
    end
  end

  # Language pairs with automatic translator assignment enable should not allow
  # anyone to some actions of this page, as we don't want translators
  # applying to those language pairs or cancelling the automatically created
  # bids, nor clients or supporters inviting translators.
  def forbid_for_autoassign_language_pairs
    fallback_path = @user.is_a?(Translator) ? '/translator' : wpml_website_path(@website)

    if @website_translation_offer.automatic_translator_assignment
      redirect_back(fallback_location: fallback_path,
                    notice: 'You cannot do this because this language pair has ' \
                            'automatic translator assignment enabled.')
      return false
    end
  end

end
