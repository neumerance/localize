class ResourceChatsController < ApplicationController
  include ::LogError
  include ::RefundCredit
  include ::TargetUsers

  prepend_before_action :setup_user
  before_action :locate_parent
  before_action :locate_chat, except: [:new, :create, :start_translations, :send_broadcast]
  before_action :verify_translator, only: [:new, :create, :review_complete, :translation_complete]
  before_action :verify_client, only: [:start_translations]
  before_action :verify_view, only: [:show]
  before_action :setup_help
  before_action :create_reminders_list, only: [:index, :show]
  layout :determine_layout

  TRANSLATION_STATUS_TEXT = { RESOURCE_CHAT_NOTHING_TO_TRANSLATE => N_('Nothing sent to translation yet.'),
                              RESOURCE_CHAT_PENDING_TRANSLATION => N_('Text sent to translation. Waiting for translator to complete the work.'),
                              RESOURCE_CHAT_TRANSLATION_COMPLETE => N_('Translator completed all pending work. Client has been notified. Review required.'),
                              RESOURCE_CHAT_TRANSLATOR_NEEDS_TO_REVIEW => N_('Translator completed all pending work. Client has been notified. Translator needs to do final review.'),
                              RESOURCE_CHAT_TRANSLATION_REVIEWED => N_('All work completed and reviewed.') }.freeze
  def new
    # resource_lang_id
    begin
      resource_language = ResourceLanguage.find(params[:resource_lang_id].to_i)
    rescue
      set_err('cannot find this resource language')
      return
    end
    if resource_language.text_resource != @text_resource
      set_err('language does not belong to project')
      return
    end

    @resource_chat = ResourceChat.new
    @resource_chat.resource_language = resource_language

    @header = _('Apply to localize application')
  end

  def create
    @resource_chat = ResourceChat.new(params[:resource_chat])
    @resource_chat.translator = @user

    if @resource_chat.resource_language_id.blank?
      set_err('language not set')
      return
    end

    if @resource_chat.resource_language.text_resource != @text_resource
      set_err('wrong project')
      return
    end

    @message = params[:message]
    @apply = params[:apply]
    ok = false

    err = false
    if @message.blank?
      @resource_chat.errors.add(:base, _('You must enter a message to the client in order to apply for this work'))
      err = true
    end

    if @apply.blank?
      @resource_chat.errors.add(:base, _('Please indicate if you are applying to this job or not'))
      err = true
    end

    unless err
      @resource_chat.status = @apply == '1' ? RESOURCE_CHAT_APPLIED : RESOURCE_CHAT_NOT_APPLIED

      ok = @resource_chat.save
      if ok
        chat_message = Message.new(body: @message, chgtime: Time.now)
        chat_message.user = @user
        chat_message.owner = @resource_chat
        chat_message.save!

        message_delivery = MessageDelivery.new
        message_delivery.user = @text_resource.client
        message_delivery.message = chat_message
        message_delivery.save
      end
    end

    if ok
      if @apply == '1'
        flash[:notice] = _('You have applied to this work')
        @text_resource.client.create_reminder(EVENT_NEW_RESOURCE_TRANSLATION_CONTRACT, @resource_chat)
        if @text_resource.contact.can_receive_emails?
          ReminderMailer.new_application_for_resource_translation(@text_resource.contact, @resource_chat, @message).deliver_now
        end
      else
        flash[:notice] = _('Your message was sent to the client')
        @text_resource.client.create_reminder(EVENT_NEW_RESOURCE_TRANSLATION_MESSAGE, @resource_chat)
        if @text_resource.contact.can_receive_emails?
          ReminderMailer.new_message_for_resource_translation(@text_resource.contact, @resource_chat, chat_message).deliver_now
        end
      end

      redirect_to(action: :show, id: @resource_chat.id)
    else
      @header = _('Apply to localize application')
      render(action: :new)
    end
  end

  def show
    @header = 'Application for app localization work'
    @can_edit = false
    @for_who = collect_target_users(@user, [@text_resource.client, @text_resource.alias, @resource_chat.translator, @manager], @resource_chat.messages)

    # Remove client if alias_id is set
    if @resource_chat.alias && @resource_chat.alias.can_receive_emails?
      @for_who.reject! { |u| u.instance_of? Client }
    end

    selected_chat = @resource_chat.resource_language.selected_chat

    @can_review = (@user[:type] == 'Translator') && (!selected_chat || (selected_chat != @resource_chat)) && (@user.level == EXPERT_TRANSLATOR) && @resource_chat.resource_language.managed_work && (@resource_chat.resource_language.managed_work.active == MANAGED_WORK_ACTIVE) && !@resource_chat.resource_language.managed_work.translator

    if selected_chat && (selected_chat != @resource_chat)
      @status_text = _('Another translator was already selected for this work.')
      @status_actions = []
    elsif @user.has_supporter_privileges? || @user.has_client_privileges?
      if @resource_chat.status == RESOURCE_CHAT_APPLIED
        @status_text = _('%s is interested in doing this translation work.') % @resource_chat.translator.full_name
        @status_actions = [[_('Accept this application'), RESOURCE_CHAT_ACCEPTED],
                           [_('Decline this application'), RESOURCE_CHAT_DECLINED]]
      elsif @resource_chat.status == RESOURCE_CHAT_ACCEPTED
        @status_text = _("You have accepted %s's application for doing this translation work.") % @resource_chat.translator.full_name
        @status_actions = [[_('Cancel the application acceptance'), RESOURCE_CHAT_DECLINED]]
      elsif @resource_chat.status == RESOURCE_CHAT_DECLINED
        @status_text = _("You have declined %s's application for doing this translation work.") % @resource_chat.translator.full_name
        @status_actions = [[_('Accept this application'), RESOURCE_CHAT_ACCEPTED]]
      else
        @status_text = _('%s did not yet apply for this work.') % @resource_chat.translator.full_name
        @status_actions = []
      end
    elsif @user[:type] == 'Translator'
      @can_complete_review = (@user == @resource_chat.translator) && (@resource_chat.translation_status == RESOURCE_CHAT_TRANSLATOR_NEEDS_TO_REVIEW) &&
                             !(@resource_chat.resource_language.managed_work && (@resource_chat.resource_language.managed_work.active == MANAGED_WORK_ACTIVE))

      if @resource_chat.status == RESOURCE_CHAT_APPLIED
        @status_text = _('You have applied for this work. The client did not make a decision yet.')
        @status_actions = [[_('Retract application'), RESOURCE_CHAT_NOT_APPLIED]]
      elsif @resource_chat.status == RESOURCE_CHAT_ACCEPTED
        @status_text = _('Your application for doing this work has been accepted.')
        @status_actions = [[_('Retract application'), RESOURCE_CHAT_NOT_APPLIED]]
        @can_edit = true
      elsif @resource_chat.status == RESOURCE_CHAT_DECLINED
        @status_text = _('Your application for doing this work has been declined.')
        @status_actions = []
      else
        @status_text = if @resource_chat.translator.private_translator?
                         'You are a private translator, and your payment will be handled between you and your client outside the system'
                       else
                         _('The rate for this project is %s USD per word.') % @resource_chat.resource_language.translation_amount
                       end
        @status_text += '<br>'
        if @resource_chat.resource_language.text_resource.client.top
          @status_text += _('This project has a special pricing for this client, any questions please open a support ticket')
          @status_text += '<br>'
        end
        @status_text += _('You did not yet apply for this work.')
        @status_actions = if (@user.userstatus == USER_STATUS_PRIVATE_TRANSLATOR) ||
                             (@user.from_languages.where('translator_languages.language_id=?', @text_resource.language_id).first &&
                             @user.to_languages.where('translator_languages.language_id=?', @resource_chat.resource_language.language_id).first)

                            [[_('Apply for this work'), RESOURCE_CHAT_APPLIED]]
                          else
                            []
                          end
      end
    end
  end

  def update_application_status
    status = params[:status].to_i

    unless @user.can_modify?(@text_resource) || @user.is_translator?
      set_err("Can't do this.")
      return
    end

    # make sure reviewers are not accepted as translators
    if (status == RESOURCE_CHAT_ACCEPTED) && @resource_chat.resource_language.managed_work && (@resource_chat.resource_language.managed_work.active == MANAGED_WORK_ACTIVE) && (@resource_chat.resource_language.managed_work.translator == @resource_chat.translator)
      flash[:notice] = _('This translator was already accepted as reviewer for the project. Choose a different translator.')
    elsif (@user == @resource_chat.translator) && (status == RESOURCE_CHAT_APPLIED) &&
          !((@user.userstatus == USER_STATUS_PRIVATE_TRANSLATOR) ||
            (@user.from_languages.where('translator_languages.language_id=?', @text_resource.language_id).first &&
            @user.to_languages.where('translator_languages.language_id=?', @resource_chat.resource_language.language_id).first))
    elsif @resource_chat.update_attributes(status: status)
      Reminder.by_owner_and_normal_user(@resource_chat, @user).destroy_all

      if (@user == @resource_chat.translator) && (status == RESOURCE_CHAT_APPLIED)
        @text_resource.client.create_reminder(EVENT_NEW_RESOURCE_TRANSLATION_CONTRACT, @resource_chat)
        if @text_resource.contact.can_receive_emails?
          ReminderMailer.new_application_for_resource_translation(@text_resource.contact, @resource_chat, nil).deliver_now
        end
      elsif @user.has_supporter_privileges? || @user.can_modify?(@text_resource)
        if status == RESOURCE_CHAT_ACCEPTED
          @resource_chat.accept
          flash[:how_to_proceed] = true
        elsif status == RESOURCE_CHAT_DECLINED
          @resource_chat.resource_language.update_attributes(status: RESOURCE_LANGUAGE_OPEN)
          if @resource_chat.translator.can_receive_emails?
            ReminderMailer.declined_application_for_resource_translation(@resource_chat.translator, @resource_chat).deliver_now
          end

          # return all strings pending translation to untranslated status and refund client
          release_strings_and_refund
        end
      end
      flash[:notice] = _('Application updated.')
    else
      flash[:notice] = _('Application could not be updated')
    end
    redirect_to action: :show, anchor: 'application_status'
  end

  def send_broadcast
    if params[:body].blank?
      flash[:notice] = _('No message entered')
    else
      @text_resource.resource_languages.each do |resource_language|
        chat = resource_language.selected_chat
        next unless chat
        if resource_language.managed_work && resource_language.managed_work.enabled?
          reviewer = resource_language.managed_work.translator
        end
        to_who = [chat.translator, reviewer]

        message = chat.create_message(@user, params)
        if message.errors.blank?
          flash[:notice] = _('Your messages were sent!')
          to_who.each { |user| user && user.notify_new_message(chat, message) }
        else
          flash[:notice] = list_errors(message.errors.full_messages)
        end
      end
    end

    redirect_to :back
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

    if (@user[:type] == 'Translator') && @user.to_lang_ids.empty? && !@user.private_translator?
      warnings << _("You don't have any language approved")
    end

    if warnings.empty?
      message = @resource_chat.create_message(@user, params)
      if message.errors.blank?
        to_who.each { |user| user.notify_new_message(@resource_chat, message) }
        flash[:ack] = _('Your message was sent!')
      else
        message.errors.full_messages.each { |x| warnings << x }
        flash[:notice] = list_errors(message.errors.full_messages)
      end
    end

    if !warnings.empty?
      @warning = warnings.collect { |w| "- #{w}." }.join("\n")
    else
      flash[:ack] = _('Your message was sent!')
      @redirect_url = url_for(action: :show, id: @resource_chat.id, anchor: 'reply', t: Time.now.to_i)
    end
    respond_to do |format|
      format.js
      format.html { @redirect_url.present? ? (redirect_to @redirect_url) : (render plain: '') }
    end
  end

  def start_translations
    msg = nil

    # parameters check
    if !params[:selected_chats] || params[:selected_chats].empty?
      msg = _('You must select at least one language to start translations')
    else

      # parameters acquisition
      text_resource = TextResource.find(params[:text_resource_id])
      resource_chats = ResourceChat.find(params[:selected_chats])
      user_account = text_resource.client.find_or_create_account(DEFAULT_CURRENCY_ID)

      # Check if the user has enough money
      if !user_account.has_enough_money_for(text_resource: text_resource, resource_chats: resource_chats)
        msg = _('Not enough money in your account for this translation')
      else
        # Start all the translations
        begin
          TextResource.transaction do
            resource_chats.each do |resource_chat|
              resource_chat.resource_language.pay
            end
          end
        rescue => error
          log_error error
          msg = _('Transaction failed')
        end
      end
    end

    flash[:notice] = msg
    redirect_to controller: :text_resources, action: :show, id: @text_resource.id
  end

  def start_review
    unreviewed_strings = @text_resource.unreviewed_strings(@resource_chat.resource_language.language)
    word_count = @text_resource.count_words(unreviewed_strings, @text_resource.language, @resource_chat.resource_language, false, "unreviewed to #{@resource_chat.resource_language.language.name}")

    amount = word_count * @resource_chat.resource_language.review_amount

    logger.info "------------ #{unreviewed_strings.length} unreviewed_strings, word_count=#{word_count}, amount=#{amount}"

    # get the source account and verify there's enough money in it
    user_account = @text_resource.client.find_or_create_account(DEFAULT_CURRENCY_ID)
    resource_language_account = @resource_chat.resource_language.find_or_create_account(DEFAULT_CURRENCY_ID)

    msg = nil
    if (user_account.balance + 0.01) >= amount

      # transfer the payment to the resource_language account
      money_transaction = MoneyTransactionProcessor.transfer_money(user_account, resource_language_account, amount, DEFAULT_CURRENCY_ID, TRANSFER_DEPOSIT_TO_RESOURCE_TRANSLATION)
      if money_transaction
        money_transaction.owner = @resource_chat.resource_language
        money_transaction.save!

        resource_language = @resource_chat.resource_language

        @resource_chat.send_strings_to_review(@text_resource, @resource_chat.resource_language, unreviewed_strings, amount)
      else
        msg = _('Transaction failed')
      end
    else
      msg = _('Not enough money in your account for this translation')
    end

    flash[:notice] = msg
    respond_to do |f|
      f.html { redirect_to controller: :text_resources, action: :show, id: @text_resource.id }
      f.js
    end
  end

  def attachment
    begin
      attachment = Attachment.find(params[:attachment_id])
    rescue
      set_err('Cannot find attachment')
      return
    end
    if attachment.message.owner != @resource_chat
      set_err("attachment doesn't belong to this chat")
      return
    end
    send_file(attachment.full_filename)
  end

  def translation_complete
    if @resource_chat.translation_status != RESOURCE_CHAT_PENDING_TRANSLATION
      flash[:notice] = _('Translation is not in progress.')
      return
    end

    admin = User.where('email=?', CMS_SUPPORTER_EMAIL).first

    self_review = false
    if @resource_chat.resource_language.managed_work && (@resource_chat.resource_language.managed_work.active == MANAGED_WORK_ACTIVE)
      @resource_chat.update_attributes(translation_status: RESOURCE_CHAT_TRANSLATION_COMPLETE, word_count: 0)

      if @resource_chat.resource_language.managed_work.translator
        @resource_chat.resource_language.managed_work.update_attributes(translation_status: MANAGED_WORK_REVIEWING)
        reviewer = @resource_chat.resource_language.managed_work.translator

        if reviewer.can_receive_emails?
          ReminderMailer.managed_work_ready_for_review(
            reviewer,
            @resource_chat.resource_language.managed_work,
            'software localization project - %s' % @text_resource.name,
            controller: :text_resources, action: :show, id: @text_resource.id
          ).deliver_now
        end

        reviewer_name = reviewer.full_name
      else
        @resource_chat.resource_language.managed_work.update_attributes(translation_status: MANAGED_WORK_WAITING_FOR_REVIEWER)
        reviewer_name = 'the reviewer'
      end
    else
      @resource_chat.update_attributes(translation_status: RESOURCE_CHAT_TRANSLATOR_NEEDS_TO_REVIEW)
      self_review = true
      reviewer_name = @resource_chat.translator.full_name
    end

    msg = "Translation is now complete and it's time to review it in the application.\n\n"
    msg += "%s, in order to let %s review the work, you can upload screen-shots of the translated application. To do this, use the 'attachments' field in this chat. %s will go over everything and make sure translations are correct in their context.\n\n" % [@text_resource.client.full_name, reviewer_name, reviewer_name.capitalize]
    if self_review
      msg += "%s, once you have reviewed everything, click on the button at the top of this chat to indicate that the project is complete and reviewed.\n\n" % reviewer_name
    end
    # msg += "We also recommend to use the post-translation QA checks. These checks will help you locate any technical issues. Go to the project page, scroll to the bottom and click on 'Post-translation QA checks'."

    message = Message.new(body: msg, chgtime: Time.now)
    message.user = admin
    message.owner = @resource_chat
    message.save!

    if @text_resource.contact.can_receive_emails?
      ReminderMailer.new_message_for_resource_translation(@text_resource.contact, @resource_chat, message).deliver_now
    end

    # if the translator is also reviewing, notify the translator too
    if self_review
      if @resource_chat.translator.can_receive_emails?
        ReminderMailer.new_message_for_resource_translation(@resource_chat.translator, @resource_chat, message).deliver_now
      end
    end

    redirect_to action: :show
  end

  # Method called when TRANSLATOR (not reviewer) completes review
  # If you are interested in the method that handles the review completation BY REVIEWER go to:
  #   ResourceStringsController#complete_review
  def review_complete
    if @resource_chat.translation_status == RESOURCE_CHAT_TRANSLATOR_NEEDS_TO_REVIEW
      @resource_chat.update_attributes!(translation_status: RESOURCE_CHAT_TRANSLATION_REVIEWED)
      msg = '%s has completed reviewing the translation. It is now safe to use it in your application.' % @user.full_name

      admin = User.where('email=?', CMS_SUPPORTER_EMAIL).first

      message = Message.new(body: msg, chgtime: Time.now)
      message.user = admin
      message.owner = @resource_chat
      message.save!

      @text_resource.client.create_reminder(EVENT_NEW_RESOURCE_TRANSLATION_MESSAGE, @resource_chat)
      if @text_resource.contact.can_receive_emails?
        ReminderMailer.new_message_for_resource_translation(@text_resource.contact, @resource_chat, message).deliver_now
      end

      # icldev-637 As we are going to move unused funds back to custemer account, deactivate any pending review string
      #  As this action is only called when review is disabled and translator is performing review This if should always be true.
      if @resource_chat.resource_language.managed_work.disabled?
        @text_resource.string_translations.where([
                                                   'string_translations.review_status IN (?) AND (string_translations.language_id=?)',
                                                   [REVIEW_PENDING_ALREADY_FUNDED, REVIEW_AFTER_TRANSLATION], @resource_chat.resource_language.language.id
                                                 ]).update_all(review_status: REVIEW_NOT_NEEDED)
      end

      refund_resource_language_leftover_credit(@resource_chat.resource_language)

      flash[:notice] = _('Thank you for reviewing the translation. We have notified the client.')
    else
      flash[:notice] = _('Translation is not complete. You can only review completed projects.')
    end

    redirect_to action: :show
  end

  private

  def verify_translator
    if @user[:type] != 'Translator'
      set_err('You cannot access this page')
      false
    end
  end

  def verify_client
    unless @user.can_modify?(@text_resource)
      set_err('You cannot access this page')
      false
    end
  end

  def locate_parent

    @text_resource = TextResource.find(params[:text_resource_id].to_i)
  rescue
    set_err('Cannot locate this project')
    return false

  end

  def locate_chat
    begin
      @resource_chat = ResourceChat.find(params[:id].to_i)
    rescue
      set_err('Cannot find this chat')
      return false
    end

    if @resource_chat.resource_language.text_resource != @text_resource
      set_err('This chat does not belong to the project')
      return false
    end

    if @user[:type] == 'Translator'
      @managed_work = @user.managed_works.where('(active=?) AND (owner_type=?) AND (owner_id=?)', MANAGED_WORK_ACTIVE, 'ResourceLanguage', @resource_chat.resource_language.id).first
    end

    if @resource_chat.resource_language.managed_work && (@resource_chat.resource_language.managed_work.active == MANAGED_WORK_ACTIVE)
      @manager = @resource_chat.resource_language.managed_work.translator
    end

    if !@user.has_supporter_privileges? && (@user != @resource_chat.translator) && ![@user, @user.master_account].include?(@text_resource.client) && !@managed_work
      set_err('You cannot access this chat')
      return false
    end
  end

  def release_strings_and_refund
    string_translations_to_release = @text_resource.string_translations.includes(:resource_string).where('(string_translations.language_id=?) AND (string_translations.status=?)', @resource_chat.resource_language.language_id, STRING_TRANSLATION_BEING_TRANSLATED)

    resource_strings = string_translations_to_release.collect(&:resource_string)

    word_count = @text_resource.count_words(resource_strings, @text_resource.language, @resource_chat.resource_language, false, nil)

    per_word_cost = @resource_chat.translation_amount

    review = @resource_chat.resource_language.managed_work && (@resource_chat.resource_language.managed_work.active == MANAGED_WORK_ACTIVE)
    per_word_cost += @resource_chat.resource_language.review_amount if review

    # amount = word_count * per_word_cost
    amount = @resource_chat.resource_language.money_accounts.try(:first).try(:balance) || 0

    # get the source account and verify there's enough money in it
    user_account = @text_resource.client.find_or_create_account(DEFAULT_CURRENCY_ID)
    resource_language_account = @resource_chat.resource_language.find_or_create_account(DEFAULT_CURRENCY_ID)

    if (resource_language_account.balance + 0.01) >= amount

      # transfer the payment to the resource_language account
      money_transaction = MoneyTransactionProcessor.transfer_money(resource_language_account, user_account, amount, DEFAULT_CURRENCY_ID, TRANSFER_REFUND_FOR_RESOURCE_TRANSLATION)
      if money_transaction
        money_transaction.owner = @resource_chat.resource_language
        money_transaction.save!

        resource_language = @resource_chat.resource_language

        # release the strings
        string_translations_to_release.each do |string_translation|
          string_translation.update_attributes(status: STRING_TRANSLATION_MISSING, pay_translator: 0, review_status: REVIEW_NOT_NEEDED, pay_reviewer: 0)
        end

        @resource_chat.update_attributes!(translation_status: RESOURCE_CHAT_NOTHING_TO_TRANSLATE, word_count: 0)

        # invalidate all cache
        @text_resource.update_version_num
      end
    end

  end

  def verify_view
    unless @user.is_translator? || @user.can_view?(@text_resource)
      set_err("You can't do that.")
      false
    end
  end

end
