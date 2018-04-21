require 'base64'

class WebMessagesController < ApplicationController
  include ::Glossary
  include ::ProcessorLinks

  prepend_before_action :setup_user, except: [:new, :pre_create, :create, :select_to_languages]
  prepend_before_action :setup_user_optional, only: [:new, :pre_create, :create, :select_to_languages]
  before_action :verify_translator, only: [:fetch_next, :hold_for_review, :hold_for_translation, :release_from_hold, :update, :edit, :final_review, :correct, :review_index, :flag_as_complex]
  before_action :verify_client, only: [:new, :pre_create, :create, :translation, :delete]
  before_action :locate_message, only: [
    :show, :hold_for_review, :hold_for_translation, :release_from_hold, :update, :translation,
    :delete, :edit, :final_review, :correct, :create_message, :review, :review_complete,
    :update_remaining_time, :enable_review
  ]
  before_action :verify_ownership, only: [:show, :release_from_hold, :update, :translation, :delete, :edit]
  before_action :verify_reviewer, only: [:review]
  before_action :set_glossary, only: [:show, :edit, :update, :final_review, :correct, :review]
  before_action :verify_create, only: [:new, :pre_create]
  before_action :set_cache_headers, only: [:edit, :final_review, :hold_for_translation]
  before_action :verify_translation_status, only: [:edit, :final_review]

  layout :determine_layout_local

  def index
    if @user.has_supporter_privileges?
      redirect_to url_for(controller: :supporter, action: :web_messages)
      return
    end

    if @user[:type] == 'Translator'
      @web_message = @user.web_message_in_progress
      if @web_message && check_and_set_remaining_time
        @current_message = @web_message
      end

      @messages = @user.open_web_messages('', 20)
      @header = _('Open Instant Translation projects')
    else

      # set up the search conditions
      @message_conditions = {}

      if !params[:set_args].blank?
        if !params[:translation_status].blank? && (params[:translation_status].to_i != 0)
          @message_conditions['translation_status'] = params[:translation_status].to_i
        end

        session[:message_conditions] = @message_conditions
      elsif session[:message_conditions]
        @message_conditions = session[:message_conditions]
      end

      conds = (@message_conditions unless @message_conditions.keys.empty?)

      @messages = @user.web_messages.where(conds).order('id DESC').page(params[:page]).per(params[:per_page])

      @missing_funding = WebMessage.missing_funding_for_user(@user)

      @header = 'Instant Translation projects'
    end

    respond_to do |format|
      format.html do
        if @user[:type] == 'Translator'
          render action: :translator_index
        else
          render action: :index
        end
      end
      format.xml
    end
  end

  def searcher
    @web_messages = if params[:project_filter].present?
                      @user.web_messages.where('web_messages.name LIKE ?', "%#{params[:project_filter]}%").order('web_messages.id DESC').page(params[:page]).per(PER_PAGE_SUMMARY)
                    else
                      @user.web_messages.order('web_messages.id DESC').page(params[:page]).per(PER_PAGE_SUMMARY)
                    end
    @web_messages_message = if @web_messages.total_pages > 1
                              _('Page %d of %d of instant translation projects') % [@web_messages.current_page, @web_messages.total_pages] +
                                "&nbsp;&nbsp;&nbsp;<a href=\"#{url_for(controller: :web_messages, action: :index)}\">" + _('Older instant translation projects') + '</a>'
                            else
                              _('Showing all your instant translation projects')
                            end
  end

  def review_index
    if @user.is_a?(Admin)
      redirect_to(controller: :supporter, action: :index) && return
    end
    @messages = @user.web_messages_for_review('', 20)
    @header = _('Instant Translation projects for review')

    respond_to do |format|
      format.html do
        if @user[:type] == 'Translator'
          render action: :review_index
        else
          render action: :index
        end
      end
      format.xml
    end
  end

  def fetch_next

    cont = true
    attempts = 3

    review = !params[:review].blank?

    @err_code = NO_MESSAGES_TO_TRANSLATE
    while cont && (attempts > 0)
      attempts -= 1
      messages = review ? @user.web_messages_for_review('', 20) : @user.open_web_messages('', 20)
      logger.info "-------- open_web_messages: #{(messages.collect { |m| m.id.to_s }).join(',')}"
      if messages.empty?
        cont = false
      else
        message = messages[0]

        amount = review ? message.reviewer_payment : message.translator_payment

        if (review ? ((message.translation_status == TRANSLATION_COMPLETE) && message.managed_work && (message.managed_work.translation_status == MANAGED_WORK_CREATED)) : ((message.translation_status == TRANSLATION_NEEDED) && message.translator_id.nil?)) &&
           ((message.money_account.balance + 0.01) >= amount) &&
           # if this fails, nothing is changed - the user can try again
           begin
             WebMessage.transaction do
               message.money_account.move_to_hold_sum(amount)

               if review
                 message.managed_work.translator = @user
                 message.managed_work.translation_status = MANAGED_WORK_REVIEWING
                 message.managed_work.save!
               else
                 message.translation_status = TRANSLATION_IN_PROGRESS
                 message.translator = @user
                 message.translate_time = Time.now # until translated, this holds the hold time
                 message.save!
               end

               @err_code = MESSAGE_HELD_FOR_TRANSLATION
               @web_message = message
               cont = false

               set_glossary
             end
           rescue
             @err_code = NO_MESSAGES_TO_TRANSLATE
             @web_message = nil
           end
        end
      end
    end

    if @web_message
      logger.info "------ Message.#{@web_message.id} held for translation by #{@user.email} (attempts=#{attempts})"
    end

    respond_to do |format|
      format.html do
        if @web_message
          if review
            redirect_to action: :review, id: @web_message.id
          else
            redirect_to action: :edit, id: @web_message.id
          end
        else
          flash[:notice] = 'Could not get that message'
          redirect_to action: :index
        end
      end
      format.xml do
        if @web_message
          render action: :fetch_next
        else
          render action: :blank
        end
      end
    end
  end

  def edit
    if @web_message.translator_id != @user.id
      logger.info "------- Translator #{@user.email} cannot edit message.#{@web_message.id} - belongs to #{@web_message.translator_id}"
      set_err('Not your message', TRANSLATION_NOT_YOUR)
      return false
    end

    @header = "Translate message (job ID: #{@web_message.id})"

    return unless check_and_set_remaining_time(true)

    @remaining_time = @web_message.remaining_time - 5

    @body = @web_message.translation
  end

  def final_review
    @header = "Review your translation (job ID: #{@web_message.id})"
    @need_additional_confirmation = !params[:need_additional_confirmation].blank?
    @title = params[:title]
    @body = params[:body]
    elapsed_time = @web_message.translate_time ? Time.now - @web_message.translate_time : 0
    @remaining_time = (@web_message.timeout - elapsed_time).to_i - 5
    return unless check_and_set_remaining_time
  end

  def correct
    return unless check_and_set_remaining_time
    @header = "Update the translation (job ID: #{@web_message.id})"
    @title = params[:title]
    @body = params[:body]
    @need_additional_confirmation = !params[:need_additional_confirmation].blank?
    @remaining_time = (@web_message.timeout - (Time.now - @web_message.translate_time)).to_i - 5
    render action: :edit
  end

  def show
    if @user.alias? && !@user.can_view?(@web_message)
      set_err('You are not allowed to access this page')
      return
    end

    @header = if !@web_message.name.blank?
                @web_message.name
              else
                _('Instant Message Details')
              end

    payment = @user[:type] == 'Translator' ? @web_message.translator_payment : @web_message.price
    @message_info = [
      [_('Status'), @web_message.translation_and_review_status],
      [_('Created on'), @web_message.create_time.strftime(TIME_FORMAT_STRING)],
      [_('Payment'), "#{payment.to_f.round(2)} USD"]
    ]

    if @user.has_to_pay_taxes?
      tax_amount = @user.calculate_tax payment
      payment += tax_amount

      @message_info << ['VAT Tax in %s (%i%%)' % [@user.country.name, @user.tax_rate.to_i], "#{tax_amount.to_f.round(2)} USD"]
      @message_info << ['Total', "#{payment.to_f.round(2)} USD"]
    end

    if @web_message.translation_status == TRANSLATION_COMPLETE
      @message_info << [_('Translated to'), @web_message.destination_language.name]
      @message_info << [_('Completed on'), @web_message.translate_time.strftime(TIME_FORMAT_STRING)] if @web_message.translate_time.present?
    else
      @message_info << [_('Translating to'), @web_message.destination_language.name]
    end

    if (@web_message.translation_status == TRANSLATION_IN_PROGRESS) && @web_message.translator
      @message_info << [_('Being translated by'), @web_message.translator.full_name]
      @message_info << [_('Translation started'), @web_message.translate_time.strftime(TIME_FORMAT_STRING)] if @web_message.translate_time.present?
    end

    @message_info << [_('Job ID'), @web_message.id]

    @review_enabled = @web_message.managed_work && @web_message.managed_work.enabled?
    @message_info << [_('Review'), (@review_enabled ? 'Enabled' : 'Disabled')]

    if @user.has_supporter_privileges? || @user == @web_message.owner
      @can_delete = [TRANSLATION_PENDING_CLIENT_REVIEW, TRANSLATION_NOT_NEEDED, TRANSLATION_NEEDED].include?(@web_message.translation_status)
      @can_modify_review_status = @web_message.can_modify_review_status
    else
      @can_delete = false
      @can_modify_review_status = false
    end

    @can_edit = (@user == @web_message.translator) && @web_message.issues.where('(status = ?) AND (target_id = ?)', ISSUE_OPEN, @user.id).first

    # set up to who it's possible to open tickets
    client = @web_message.owner.class == Client ? @web_message.owner : nil

    @potential_users = []
    if (@user == client || @user.alias_of?(client)) && @web_message.translator
      @potential_users = [[@web_message.translator, 'Translator']]
      if @web_message.managed_work && (@web_message.managed_work.active == MANAGED_WORK_ACTIVE) && @web_message.managed_work.translator
        @potential_users += [[@web_message.managed_work.translator, 'Reviewer']]
      end
    elsif (@user == @web_message.translator) && client
      @potential_users = [[client, 'Client']]
      if @web_message.managed_work && (@web_message.managed_work.active == MANAGED_WORK_ACTIVE) && @web_message.managed_work.translator
        @potential_users += [[@web_message.managed_work.translator, 'Reviewer']]
      end
    elsif @web_message.managed_work && (@web_message.managed_work.active == MANAGED_WORK_ACTIVE) && @web_message.managed_work.translator
      @potential_users = [[client, 'Client']] if client
      if @web_message.translator
        @potential_users += [[@web_message.translator, 'Translator']]
      end
    end

    respond_to do |format|
      format.html
      format.xml
    end
  end

  def translation
    if @user.alias? && !@user.can_view?(@web_message)
      set_err('You are not allowed to access this page')
      return
    end
    send_data(@web_message.decoded_translation(@user),
              filename: "instant_translation#{@web_message.id}.txt",
              type: 'text/plain',
              disposition: 'downloaded')
  end

  def flag_as_complex
    @back = '/web_messages'
    @web_message = WebMessage.find(params[:id])
    if @web_message.nil?
      @error = "This instant translation project dosen't exists anymore."
      return
    end

    flags = if @web_message.complex_flag_users
              YAML.load(@web_message.complex_flag_users)
            else
              []
            end

    @web_message.release_from_hold
    if flags.include?(@user.id)
      @error = 'You already marked this instant translation project as complex.'
      return
    end

    flags << @user.id
    if flags.size == WEB_MESSAGE_COMPLEX_N_FLAGS
      if @web_message.client.try(:can_receive_emails?)
        InstantMessageMailer.flagged_as_complex(@web_message).deliver_now
      end
    end

    @web_message.complex_flag_users = flags.to_yaml

    unless @web_message.save
      @error = 'An error ocurred. Please try again.'
      return
    end
  end

  def delete
    # this is done within a transaction to guarantee that status check is inline with deletion
    # this transaction will guarantee that translators cannot hold the message while we delete it
    ok = false
    WebMessage.transaction do
      if [TRANSLATION_PENDING_CLIENT_REVIEW, TRANSLATION_NOT_NEEDED, TRANSLATION_NEEDED].include?(@web_message.translation_status)
        begin
          @web_message.update_attributes!(translation_status: TRANSLATION_NOT_NEEDED)
          ok = true
        rescue
        end
      end
    end
    ok = @web_message.destroy if ok

    if ok
      flash[:notice] = _('Project deleted')
      url = if %w(Admin Supporter).include? @user.type
              url_for(controller: :supporter, action: :web_messages)
            else
              url_for(action: :index)
            end
      redirect_to url
    else
      flash[:notice] = _('Project could not be deleted')
      redirect_to(action: :show, id: @web_message.id)
    end
  end

  def new
    @web_message = WebMessage.new(client_language_id: 1)
    @languages = Language.have_translators([])

    @cancel_link = if request.referer
                     request.referer
                   elsif @user
                     { action: :index }
                   else
                     '/instant-text-translation.html'
                   end

    @header = if @user
                _('Create a new Instant Translation project')
              else
                _('Quote for Text Translation')
              end

    session[:web_message] = nil
  end

  def pre_create
    @web_message = WebMessage.new(params[:web_message])
    @web_message.valid?
    @web_message.notified = 0
    @web_message.errors.add(:client_body, _('No text entered')) unless params[:web_message][:client_body].present?

    unless @web_message.client_body.blank?
      logger.info @web_message.client_body_for_word_count
      asian_language = Language.asian_language_ids.include?(@web_message.client_language_id)
      @web_message.word_count = if asian_language
                                  (@web_message.client_body_for_word_count.length / UTF8_ASIAN_WORDS).ceil
                                else
                                  @web_message.client_body_for_word_count.split_text.length
                                end
      if @web_message.word_count > 500
        @web_message.errors.add(:base, _("This text contains %d words. The maximum length for Instant Translation projects is 500 words.\nTo translate longer texts, please create a bidding project.") % @web_message.word_count)
      end
    end

    @currency = Currency.find(DEFAULT_CURRENCY_ID)

    # TODO: fix ActionDispatch::Cookies::CookieOverflow
    # session limit is 4kb
    # refactor or use https://github.com/rails/activerecord-session_store
    # spetrunin 10/18/2016
    session[:web_message] = @web_message
    if @web_message.errors.count > 0
      @languages = Language.list_major_first
      if @user
        @cancel_link = { action: :index }
        @header = _('Create a new Instant Translation project')
      else
        @cancel_link = '/instant-text-translation.html'
        @header = _('Quote for Text Translation')
      end
      render(action: :new)
      return
    end
    @header = _('Select languages to translate to')
    @text_title = _('Original text in %s') % @web_message.client_language.name

    create_to_languages
  end

  def select_to_languages
    @total_cost = 0
    @tax_amount = 0
    req = params[:req]
    @web_message = session[:web_message]
    @warning = nil
    ok = false

    @currency = Currency.find(DEFAULT_CURRENCY_ID)

    return unless @web_message
    if req == 'show'
      create_to_languages

      to_language_ids = session[:to_language_ids]
      @selected_to_languages = Language.where('id IN (?)', to_language_ids)
      @selected_to_languages.each { |lang| @to_languages[lang.name] = [lang.id, true, lang.major] }
      @edit_language = true
      ok = true

    elsif req.nil?
      # set the review status
      session[:web_message] = @web_message

      # @web_message.owner = @user

      # set the destination languages
      begin
        to_language_ids = make_dict(params[:language])
      rescue
        to_language_ids = []
      end
      if to_language_ids.empty?
        @warning = _('No language selected')
      else
        session[:to_language_ids] = to_language_ids
        review = params[:review].to_i == 1
        session[:review] = review
        @selected_to_languages = Language.where('id IN (?)', to_language_ids)

        @total_cost = @selected_to_languages.length * @web_message.price
        @total_cost *= 1.5 if review

        if @user && @user.has_to_pay_taxes?
          @tax_amount = @user.calculate_tax @total_cost
        end

        ok = true
      end

    elsif req == 'cancel'
      to_language_ids = session[:to_language_ids]
      @selected_to_languages = Language.where('id IN (?)', to_language_ids)
      @total_cost = @selected_to_languages.length * @web_message.client_cost
      @total_cost *= 1.5 if session[:review]
      ok = true
    end
    @total = (@total_cost || 0) + (@tax_amount || 0)
    # needs to be loaded at the end, in order to be correct
    @review = session[:review]
    @ok = ok
  end

  def create
    web_message = session[:web_message]
    to_language_ids = session[:to_language_ids]
    review = session[:review]

    if !web_message || !to_language_ids || to_language_ids.empty?
      redirect_to action: :index
      return
    end

    by_normal_user = !@user.nil?

    @user = TemporaryUser.gen_new unless @user

    ActiveRecord::Base.transaction do
      message_with_language = nil

      to_language_ids.each do |lang_id|
        message_with_language = WebMessage.new(name: web_message.name,
                                               comment: web_message.comment,
                                               client_body: web_message.client_body,
                                               word_count: web_message.word_count,
                                               client_language_id: web_message.client_language_id,
                                               visitor_language_id: lang_id,
                                               translation_status: TRANSLATION_NEEDED,
                                               notified: 0,
                                               create_time: Time.now)

        message_with_language.owner = @user.alias? ? @user.master_account : @user
        message_with_language.user = @user
        message_with_language.money_account = @user.get_money_account(DEFAULT_CURRENCY_ID)
        message_with_language.save!

        next unless review
        managed_work = ManagedWork.new(active: MANAGED_WORK_ACTIVE, translation_status: MANAGED_WORK_CREATED)
        managed_work.owner = message_with_language
        managed_work.from_language = web_message.client_language
        managed_work.to_language_id = lang_id
        managed_work.client = @user
        managed_work.notified = 0
        managed_work.save!
      end
      web_message = message_with_language

      if by_normal_user
        @funding_ok = (WebMessage.missing_funding_for_user(@user) == 0)
        if @funding_ok
          @header = 'Your Instant Translation project is now complete'
        else
          @header = 'Text submitted, translation is pending payment'
          redirect_to(controller: :web_supports, action: :untranslated_messages)
        end
      else
        curtime = Time.now

        amount = web_message.client_cost * to_language_ids.length
        invoice = Invoice.new(kind: Invoice::INSTANT_TRANSLATION_PAYMENT,
                              payment_processor: EXTERNAL_ACCOUNT_PAYPAL,
                              currency_id: DEFAULT_CURRENCY_ID,
                              gross_amount: amount,
                              status: TRANSFER_PENDING,
                              create_time: curtime,
                              modify_time: curtime,
                              source: web_message)

        invoice.user = @user.alias? ? @user.master_account : @user
        invoice.set_tax_information

        invoice.save!

        to_account = @user.find_or_create_account(DEFAULT_CURRENCY_ID)

        money_transaction = MoneyTransaction.new(amount: amount,
                                                 currency_id: DEFAULT_CURRENCY_ID,
                                                 chgtime: curtime,
                                                 status: TRANSFER_PENDING,
                                                 operation_code: TRANSFER_DEPOSIT_FROM_EXTERNAL_ACCOUNT)
        money_transaction.owner = invoice
        money_transaction.target_account = to_account
        money_transaction.save!

        uri = paypal_pay_invoice(invoice, @user, url_for(controller: :web_messages, action: :new))
        redirect_to uri
      end
    end
  end

  def hold_for_review
    managed_work = @web_message.managed_work
    unless managed_work
      flash[:notice] = "can't be reviewed"
      redirect_to(action: :review_index)
      return
    end

    unless (@user.from_languages.include?(managed_work.from_language) &&
           @user.to_languages.include?(managed_work.to_language)) ||
           (@web_message.client && @web_message.client.all_private_translators.include?(@user))
      flash[:notice] = "You can't translate from/to this languages"
      redirect_to action: 'index'
      return
    end

    if (@web_message.translation_status == TRANSLATION_COMPLETE) &&
       (managed_work.translation_status == MANAGED_WORK_CREATED) &&
       [@user, nil].include?(managed_work.translator)

      WebMessage.transaction do
        MoneyAccount.transaction do
          amount = @web_message.reviewer_payment
          if @web_message.money_account.balance >= amount
            @web_message.money_account.move_to_hold_sum(amount)

            @web_message.managed_work.translator = @user
            @web_message.managed_work.translation_status = MANAGED_WORK_REVIEWING
            @web_message.managed_work.save!

            set_glossary
          else
            flash[:notice] = "Client doesn't have enough money"
            redirect_to(action: :review_index)
            return
          end
        end
      end
    else
      flash[:notice] = 'Someone else is reviewing it'
      redirect_to(action: :review_index)
      return
    end

    redirect_to action: :review, id: @web_message.id
  end

  def hold_for_translation
    return redirect_to(action: :index) if @user.web_message_in_progress

    unless @web_message.owner.is_a? WebDialog
      unless (@user.from_languages.include?(@web_message.client_language) &&
             @user.to_languages.include?(@web_message.visitor_language)) ||
             (@web_message.client && @web_message.client.all_private_translators.include?(@user))
        flash[:notice] = "You can't translate from/to this languages"
        redirect_to action: 'index'
        return
      end
    end

    # try to do a complete transaction, placing the work on hold for translation
    @err_code = HOLD_FOR_TRANSLATION_FAILED

    amount = @web_message.translator_payment

    if (@web_message.translator_id == @user.id) && request.format.html?
      redirect_to action: 'edit', id: @web_message.id
      return
    elsif (@web_message.translation_status != TRANSLATION_NEEDED) || !@web_message.translator_id.nil?
      @err_code = MESSAGE_ALREADY_ASSIGNED
    elsif @web_message.money_account.balance < amount
      @err_code = INSUFFICIENT_FUNDS_TO_HOLD_MESSAGE
      flash[:notice] = "Client doesn't have enough funds to complete this job"
      redirect_to(action: :index) && return
    else
      # i if this fails, nothing is changed - the user can try again
      begin
        WebMessage.transaction do
          curtime = Time.now
          @web_message.money_account.move_to_hold_sum(amount)

          @web_message.translation_status = TRANSLATION_IN_PROGRESS
          @web_message.translator = @user
          @web_message.translate_time = curtime # until translated, this holds the hold time
          @web_message.save!

          @err_code = MESSAGE_HELD_FOR_TRANSLATION
          @remaining_time = (@web_message.timeout - (Time.now - @web_message.translate_time)).to_i - 5
        end
      rescue => e
        logger.info e.message
        logger.info e.backtrace
      end
    end

    respond_to do |format|
      format.html { render action: 'edit' }
      format.xml { render action: :blank }
    end
  end

  def release_from_hold
    @err_code = @web_message.release_from_hold

    if @err_code == MESSAGE_RELEASED_FROM_HOLD
      logger.info "------- WebMessage.#{@web_message.id} released from hold"
      flash[:notice] = _('Text translation canceled')
    else
      logger.info "------- WebMessage.#{@web_message.id} cannot be released from hold"
      flash[:notice] = _('Something went wrong when trying to release the project from hold.')
    end

    respond_to do |format|
      format.html { redirect_to action: :index }
      format.xml { render action: :blank }
    end
  end

  def update
    # TODO: cleanup this method after replacing TA with WebTA
    body = params[:body]
    title = params[:title]
    plaintext = (params[:plaintext].to_i == 1)
    ignore_warnings = (params[:ignore_warnings].to_i == 1)

    @err_code = TRANSLATION_COMPLETION_FAILED
    @warnings = []
    continue = true

    # The web UI sends a plain text body. The desktop TA sends an encoded body.
    if plaintext
      decoded_body = body
    else
      begin
        # The desktop TA sometimes encodes the body twice or more times. See
        # https://onthegosystems.myjetbrains.com/youtrack/issue/icldev-1947
        decoded_body = Base64.decode64(body)
        5.times do
          break unless is_base64_encoded?(decoded_body)
          decoded_body = Base64.decode64(decoded_body)
        end
      rescue
        decoded_body = nil
      end
    end

    # The web UI sends a plain text title. The desktop TA sends an encoded title.
    if plaintext
      decoded_title = title
    else
      begin
        # The desktop TA sometimes encodes the title twice or more times. See
        # https://onthegosystems.myjetbrains.com/youtrack/issue/icldev-1947
        decoded_title = Base64.decode64(title)
        5.times do
          break unless is_base64_encoded?(decoded_title)
          decoded_title = Base64.decode64(decoded_title)
        end
      rescue
        decoded_title = nil
      end
    end

    need_title_translation = @web_message.need_title_translation
    decoded_body.force_encoding('utf-8')

    if update_error(body, title, need_title_translation, decoded_body, decoded_title, plaintext)
      Rails.logger.info "Error updating web message: #{@err_code}"
      continue = false
    end

    if continue && !@web_message.user_id.blank?
      untokenized_text, problems = @web_message.update_token_data(decoded_body, @web_message.client_body)
      if problems.any?
        Rails.logger.info "Missing token: #{problems.join("\n")}"
        @err_code = TRANSLATION_MISSING_TOKENS
        @warnings = problems
        continue = false
      end
    end

    if continue && update_problems(need_title_translation, decoded_title, decoded_body)
      Rails.logger.info "Update problems: #{@warnings}"
      @err_code = TRANSLATION_REQUIRES_REVIEW
      continue = false
    end

    if continue
      if @web_message.user_id.blank?
        @web_message.update_text(decoded_body, decoded_title, need_title_translation)
      else
        @web_message.update_translation(decoded_body, decoded_title, need_title_translation)
      end

      @err_code = if @web_message.translation_in_progress?
                    @web_message.complete_translation
                  else
                    TRANSLATION_COMPLETED_OK
                  end

      if @err_code == TRANSLATION_COMPLETED_OK
        if @web_message[:owner_type] == 'WebDialog' && @web_message.user_id.blank?
          if @web_message.owner.client_department.web_support.client.can_receive_emails?
            InstantMessageMailer.notify_client(@web_message.owner, @web_message, false).deliver_now
          end
        elsif @web_message[:owner_type] == 'WebDialog'
          set_locale_for_lang(@web_message.owner.visitor_language)
          if @web_message.owner.can_receive_emails?
            InstantMessageMailer.notify_visitor(@web_message.owner, @web_message, @web_message.owner.visitor_language).deliver_now
          end
          set_locale(@locale)
        elsif (@web_message[:owner_type] == 'User') || (@web_message[:owner_type] == 'NormalUser') || (@web_message[:owner_type] == 'Client')
          if @web_message.owner.can_receive_emails?
            InstantMessageMailer.instant_translation_complete(@web_message).deliver_now
          end
        elsif @web_message[:owner_type] == 'Website'
          unless @web_message.owner.send_translated_message(@web_message)
            @web_message.update_attributes(translation_status: TRANSLATION_NOT_DELIVERED)
          end
        end
      end
    end

    logger.info "--------- Message.#{@web_message.id} update completed with code=#{@err_code}"

    respond_to do |format|
      format.html do
        flash[:notice] = WebMessage::TRANSLATION_UPDATE_TEXT[@err_code]
        if [TRANSLATION_COMPLETED_OK, TRANSLATION_NOT_YOUR, TRANSLATION_ALREADY_COMPLETED].include?(@err_code)
          if @web_message.issues.where('(status = ?) AND (target_id = ?)', ISSUE_OPEN, @user.id).first
            redirect_to action: :show
          else
            redirect_to action: :index
          end
        else
          return unless check_and_set_remaining_time
          @body = body
          @title = title
          @header = "Update the translation (job ID: #{@web_message.id})"
          render action: :edit
        end
      end
      format.xml { render action: :blank }
    end
  end

  def enable_review
    unless @user.can_modify?(@web_message)
      set_err("You can't do this")
      return false
    end

    if @web_message.managed_work
      @web_message.managed_work.activate
    else
      managed_work = ManagedWork.new(active: MANAGED_WORK_ACTIVE, translation_status: MANAGED_WORK_CREATED)
      managed_work.owner = @web_message
      managed_work.from_language = @web_message.client_language
      managed_work.to_language_id = @web_message.visitor_language.id
      managed_work.client = @web_message.owner.is_a?(Website) ? @web_message.owner.client : @web_message.owner
      managed_work.notified = 0
      managed_work.save!
    end
  end

  def review
    @header = 'Review the translation'
  end

  def review_complete
    unless @web_message.try(:managed_work).try(:translation_status) == MANAGED_WORK_REVIEWING
      set_err('This text is not being reviewed right now')
      return
    end
    @web_message.review_complete

    flash[:notice] = _('Review is complete!')
    redirect_to(action: :review_index)

  end

  def update_remaining_time
    remaining_time_to_translate = (@web_message.timeout - (Time.now - @web_message.translate_time)).to_i

    warning = nil

    # check if it isn't timeout yet
    if remaining_time_to_translate <= 0
      remaining_time_to_translate = 0
      err_code = @web_message.release_from_hold
      if err_code == MESSAGE_RELEASED_FROM_HOLD
        warning = 'Translation timed out. Releasing job.'
      end
    elsif remaining_time_to_translate <= 120
      warning = 'Translation will time out very soon! If you are done, please submit the translation.'
    end

    message = '<p>Remaining time to translate:'
    message += remaining_time_to_text(remaining_time_to_translate)
    message += '.</p>'

    render html: (message + (warning ? '<p class="warning">' + warning + '</p>' : ''))

  end

  def unassign_translator
    return unless @user.has_supporter_privileges?

    if WebMessage.find(params[:id]).release_from_hold == MESSAGE_RELEASED_FROM_HOLD
      render html: "<span style='font-weight:bold; color:red;'>(Removed)</span>"
    else
      render html: "<span style='font-weight:bold; color:red;'>Error! not removed!</span>"
    end
  end

  private

  def verify_translation_status
    unless @web_message.user_can_edit? @user
      redirect_to url_for(action: :index), notice: "Job ID #{@web_message.id} is not in progress." if @web_message.translator == @user
    end
  end

  def setup_user_optional
    setup_user(false)
  end

  def locate_message
    @web_message = WebMessage.find(params[:id].to_i)
  rescue
    set_err('The message cannot be located')
    return false

  end

  def verify_translator
    if !@user[:type] == 'Translator'
      set_err('Only translators can do this')
      false
    end
  end

  def verify_client
    if @user && !@user.has_client_privileges?
      set_err('Only clients can do this')
      false
    end
  end

  def verify_reviewer
    unless @web_message.managed_work && (@web_message.managed_work.active == MANAGED_WORK_ACTIVE) && (@web_message.managed_work.translator == @user)
      set_err('You are not the reviewer for this job')
      false
    end
  end

  def verify_ownership
    if @user.has_supporter_privileges?
      true
    elsif @user[:type] == 'Translator'
      if !@web_message.translator
        true
      elsif @user.id == @web_message.translator_id
        true
      elsif @web_message.managed_work && (@web_message.managed_work.active == MANAGED_WORK_ACTIVE) && (@user == @web_message.managed_work.translator)
        true
      else
        set_err('Not your message', TRANSLATION_NOT_YOUR)
        false
      end
    elsif @user.has_client_privileges?
      if ((@web_message.owner_type == 'WebDialog') && (@web_message.owner.client_department.web_support.client_id != @user.id)) ||
         (((@web_message.owner_type == 'User') || (@web_message.owner_type == 'NormalUser') || (@web_message.owner_type == 'Client')) && ![@user, @user.master_account].include?(@web_message.owner))
        set_err('Not your message', TRANSLATION_NOT_YOUR)
        false
      end
    end
  end

  def determine_layout_local
    if @user || !request.format.html?
      determine_layout
    else
      'web_messages'
    end
  end

  def create_to_languages
    @to_languages = {}

    to_lang = Language.to_languages_with_translators(@web_message.client_language_id, true)
    to_lang.each do |lang|
      @to_languages[lang.name] = [lang.id, false, lang.major]
    end
    @edit_language = true

    @review = session[:review]
  end

  # This method has multiple responsabilites:
  #  - Sets remaining time to translate
  #  - Release from hold if needed
  #     - If attr redirect is set to true, it redirects to index
  #     - sets @err_code
  #
  #  Returns false if there is no more time to translate.
  def check_and_set_remaining_time(redirect = false)

    if (@web_message.translator == @user) && @web_message.translation_complete?
      return true
    end

    # calculate the timeout for the message
    @remainig_time_to_translate = @web_message.remaining_time

    # check if it isn't timeout yet
    if @remainig_time_to_translate <= 0
      @err_code = @web_message.release_from_hold

      if @err_code == MESSAGE_RELEASED_FROM_HOLD
        logger.info "------- Message.#{@web_message.id} released from hold"
        flash[:notice] = _("Job ID #{@web_message.id} has been released from you, maximum time for translating has been exceeded.")
      else
        logger.info "------- Message.#{@web_message.id} cannot be released from hold"
      end

      redirect_to action: :index if redirect
      return false
    end

    # make sure that the browser will refresh too
    @session_timeout = @remainig_time_to_translate
    @remaining_time_to_translate_message = remaining_time_to_text(@remainig_time_to_translate)

    true
  end

  def remaining_time_to_text(remaining_time)
    remaining_minutes = remaining_time / 60
    remaining_seconds = remaining_time % 60

    min_keyword = remaining_minutes > 1 ? 'minutes' : 'minute'
    sec_keyword = remaining_seconds > 1 ? 'seconds' : 'second'

    ret = ''
    ret += " #{remaining_minutes} #{min_keyword}" if remaining_minutes > 0
    ret += ' and' if (remaining_minutes > 0) && (remaining_seconds > 0)
    ret += " #{remaining_seconds} #{sec_keyword}" if remaining_seconds > 0
    ret
  end

  def set_glossary
    @client = nil

    if @web_message.owner.class == WebDialog
      @client = @web_message.owner.client_department.web_support.client
    elsif @web_message.owner.class == Client
      @client = @web_message.owner
    end

    if @client
      set_glossary_edit(@client, @web_message.original_language, [@web_message.destination_language])
    end
  end

  def verify_create
    unless !@user || @user.can_create_projects?
      set_err _("You can't create projects")
      false
    end
  end

  def verify_view
    unless @user.can_view?(@web_message)
      set_err _("You can't view this project")
      false
    end
  end

  def update_error(body, title, need_title_translation, decoded_body, decoded_title, plaintext)
    if (@web_message.translation_status != TRANSLATION_IN_PROGRESS) && (@web_message.translator != @user)
      @err_code = TRANSLATION_ALREADY_COMPLETED
    elsif body.blank? || (need_title_translation && title.blank?)
      @err_code = BLANK_TRANSLATION_ENTERED
    elsif decoded_body.blank? || (need_title_translation && decoded_title.blank?)
      @err_code = TRANSLATION_FAILED_TO_DECODE
    elsif !plaintext && ((Digest::MD5.hexdigest(body) != params[:body_md5]) || (need_title_translation && (Digest::MD5.hexdigest(title) != params[:title_md5])))
      @err_code = TRANSLATION_COMPLETION_FAILED
    else
      false
    end
  end

  def update_problems(need_title_translation, decoded_title, decoded_body)
    problems = []

    if need_title_translation
      original_title = @web_message.title_to_translate(false)
      if decoded_title.delete(' ') == original_title.delete(' ')
        @warnings << 'The translated title is identical to the original title'
      # elsif similar_texts?(decoded_title, original_title)
      #  @warnings << 'The translated title very similar to the original title'
      elsif decoded_title.length < (original_title.length / 2).to_i
        @warnings << 'The translated title appears to be very short'
      elsif decoded_title.length > (original_title.length * 2)
        @warnings << 'The translated title appears to be very long'
      end
    end

    original_text = @web_message.text_to_translate(false)
    if decoded_body.delete(' ') == original_text.delete(' ') && original_text.count_words > 1
      @warnings << 'The translated body is identical to the original body'
    end
  end

  def is_base64_encoded?(string)
    Base64.encode64(Base64.decode64(string)) == string
  end
end
