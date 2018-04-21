class ResourceStringsController < ApplicationController
  include ::Glossary
  include ::RefundCredit

  prepend_before_action :setup_user
  before_action :locate_parent
  before_action :locate_string, except: [:index, :size_report, :new, :create, :set_display_instructions, :delete_selected, :find_mismatching, :convert_selected, :add_auto_comments]
  before_action :locate_translation, only: [:edit_translation, :update_translation, :complete_review]
  before_action :verify_client, only: [:size_report, :edit, :update, :destroy, :remove_master, :delete_selected, :find_mismatching, :convert_selected]
  before_action :setup_help
  before_action :create_reminders_list, only: [:index, :show]
  layout :determine_layout

  include CharConversion

  def index
    @header = _('Strings for translation')
    @languages = if [@user, @user.master_account].include?(@text_resource.client) || @user.has_supporter_privileges?
                   @text_resource.resource_languages.collect(&:language)
                 else
                   @edit_languages
                 end
    language_ids = @languages.collect(&:id)

    @possible_status = [['All strings', 0], ['Untranslated strings', 1], ['Translation complete', 2]]

    # set up the search conditions
    @exact_match = false
    @status = 0

    if !params[:set_args].blank?
      @file = params[:file] unless params[:file].blank?
      @token = params[:token] unless params[:token].blank?
      @txt = params[:txt] unless params[:txt].blank?
      @translation = params[:translation] unless params[:translation].blank?
      @status = params[:status].to_i
      @exact_match = !params[:exact_match].blank?
      @exclude_duplicates = !params[:exclude_duplicates].blank?
      @size_ratio = params[:size_ratio]
      @per_page = params[:per_page] ? params[:per_page].to_i : 20
      @per_page = 100  if @per_page > 100
      session[:file] = @file
      session[:token] = @token
      session[:txt] = @txt
      session[:translation] = @translation
      session[:status] = @status
      session[:exact_match] = @exact_match
      session[:exclude_duplicates] = @exclude_duplicates
      session[:size_ratio] = @size_ratio
      session[:per_page] = @per_page || 20
    else
      get_filter_from_session
    end

    conds, cond_args = prepare_filter_conditions

    if !conds.empty?
      @filter = true
      conditions = [conds.join(' AND ')] + cond_args
    else
      conditions = nil
    end

    resource_strings = @text_resource.resource_strings.joins(:string_translations).where(conditions).uniq(&:id)
    @pager = ::Paginator.new(resource_strings.count, @per_page) do |offset, per_page|
      resource_strings.limit(per_page).offset(offset).order('resource_strings.id ASC')
    end

    @resource_strings = @pager.page(params[:page])
    @list_of_pages = (1..@pager.number_of_pages).to_a
    @show_number_of_pages = (@pager.number_of_pages > 1)

    # check if this is a reviewer
    if @user.has_translator_privileges? && @managed_resource_languages.map { |x| x.managed_work.translator_id }.include?(@user.id)
      @is_reviewer = true
      @next_in_progress_str = @text_resource.next_string(nil, language_ids,
                                                         conds + ['(string_translations.status IN (?)) AND (string_translations.review_status = ?)'],
                                                         cond_args + [[STRING_TRANSLATION_COMPLETE], REVIEW_PENDING_ALREADY_FUNDED])
      @next_label = 'review'
    else
      untranslated_status = @user[:type] == 'Translator' ? [STRING_TRANSLATION_BEING_TRANSLATED] : [STRING_TRANSLATION_MISSING, STRING_TRANSLATION_NEEDS_UPDATE]

      @next_in_progress_str = @text_resource.next_string(nil, language_ids, conds + ['(string_translations.status IN (?))'], cond_args + [untranslated_status])
      @next_label = 'translate'

      # for translators, create a list of completed languages
      if @user[:type] == 'Translator'
        @completed_chats = []
        @text_resource.resource_chats.where('(resource_chats.translator_id=?) AND (resource_chats.status=?)', @user.id, RESOURCE_CHAT_ACCEPTED).each do |resource_chat|
          if resource_chat.need_to_declare_as_complete
            @completed_chats << resource_chat
          end
        end
      end
    end
  end

  def change_label
    unless @user.has_supporter_privileges?
      set_err("You can't do that")
      return
    end

    @resource_string.update_attribute :token, params[:label]
    flash[:notice] = 'Label updated'
    redirect_to :back
  end

  def size_report
    @header = _('Post-translation QA report for project "%s"') % @text_resource.name
    @languages = @text_resource.resource_languages.collect(&:language)
    resource_strings = @text_resource.resource_strings.joins(:string_translations).where('(string_translations.txt IS NOT NULL) AND (string_translations.status = ?) AND (string_translations.language_id in (?))', STRING_TRANSLATION_COMPLETE, @languages.collect(&:id))
    @sizes = {}
    @above_user_limit = {}
    @languages.each do |language|
      @sizes[language] = {}
      @above_user_limit[language] = 0
    end
    @formatting_mismatch = []

    ratios_map = {}
    resource_strings.each do |resource_string|
      resource_string.string_translations.each do |st|
        # check lengths
        unless st.size_ratio.nil?
          # check against user specified sizes
          if resource_string.max_width && ((st.size_ratio * 100) > resource_string.max_width)
            @above_user_limit[st.language] += 1
          end

          # check for the standard steps
          size_ratio = (st.size_ratio * 10).to_i
          ratios_map[size_ratio] = true unless ratios_map.key?(size_ratio)
          sz = @sizes[st.language]
          if sz.key?(size_ratio)
            sz[size_ratio] += 1
          else
            sz[size_ratio] = 1
          end
        end

        # check formatting issues
        match = true

        my_pos = st.required_text_position
        orig_pos = resource_string.required_text_position

        if my_pos.length != orig_pos.length
          match = false
        else
          for idx in (0...my_pos.length)
            match = false if my_pos[idx] != orig_pos[idx]
          end
        end

        @formatting_mismatch << st unless match
      end
    end
    @ratios = ratios_map.keys.sort
  end

  def new
    @header = _('Add a new string to the project')
    @resource_string = ResourceString.new
  end

  def create
    @resource_string = ResourceString.new(params[:resource_string])
    @resource_string.text_resource = @text_resource

    if @text_resource.resource_strings.where('token=?', @resource_string.token).first
      @resource_string.errors.add(:base, 'A string with this label already exists in the project.')
      render action: :new
      return
    end

    if @resource_string.save
      # add blank translations
      @text_resource.resource_languages.each do |rl|
        string_translation = StringTranslation.create!(language_id: rl.language_id, txt: nil, resource_string_id: @resource_string.id, status: STRING_TRANSLATION_MISSING)
      end

      @text_resource.update_version_num

      flash[:notice] = _('Resource string added. You can now edit existing translations.')
      redirect_to action: :show, id: @resource_string.id
    else
      render action: :new
    end
  end

  def show
    # check if we're auto editing
    if params[:lang_id].to_i > 0
      return unless locate_translation
    end

    @header = _('View string translation')

    @languages =  if [@user, @user.master_account].include?(@text_resource.client) || @user.has_supporter_privileges?
                    @text_resource.resource_languages.collect(&:language)
                  else
                    @edit_languages
                  end

    # for clients, send a blank list of language IDs to filter by
    language_ids = if [@user, @user.master_account].include?(@text_resource.client) || @user.has_supporter_privileges?
                     nil
                   else
                     @languages.collect(&:id)
                   end

    @translations = {}
    @resource_string.string_translations.each { |st| @translations[st.language_id] = st }

    get_filter_from_session
    conds, cond_args = prepare_filter_conditions

    # check if this is a reviewer
    if !@managed_resource_languages.empty?
      untranslated_status = [STRING_TRANSLATION_COMPLETE]
      @prev_in_progress_str = @text_resource.prev_string(@resource_string, language_ids, conds + ['(string_translations.status IN (?)) AND (string_translations.review_status = ?)'], cond_args + [untranslated_status, REVIEW_PENDING_ALREADY_FUNDED])
      @next_in_progress_str = @text_resource.next_string(@resource_string, language_ids, conds + ['(string_translations.status IN (?)) AND (string_translations.review_status = ?)'], cond_args + [untranslated_status, REVIEW_PENDING_ALREADY_FUNDED])
      @next_label = 'review'
    else
      untranslated_status = @user[:type] == 'Translator' ? [STRING_TRANSLATION_BEING_TRANSLATED] : [STRING_TRANSLATION_MISSING, STRING_TRANSLATION_NEEDS_UPDATE]
      @prev_in_progress_str = @text_resource.prev_string(@resource_string, language_ids, conds + ['(string_translations.status IN (?))'], cond_args + [untranslated_status])
      @next_in_progress_str = @text_resource.next_string(@resource_string, language_ids, conds + ['(string_translations.status IN (?))'], cond_args + [untranslated_status])
      @next_label = 'translate'
    end

    @prev_str = @text_resource.prev_string(@resource_string, language_ids, conds, cond_args)
    @next_str = @text_resource.next_string(@resource_string, language_ids, conds, cond_args)

    if @user[:type] == 'Translator'
      @translator_chat = @text_resource.resource_chats.where('translator_id=?', @user.id).first
    end

    is_last = @prev_in_progress_str.blank? && @next_in_progress_str.blank?
    session[:is_last] = is_last

    @col_width = (85 / (@languages.length + 1)).ceil.to_s + '%'

    session[:next_in_progress_str_id] = @next_in_progress_str&.id
    session[:resource_string_id] = @resource_string.id

    do_string_edit
    @editing = false
    @editing = true if params[:lang_id].to_i > 0

    if request.xhr?
      render layout: false
      return
    end

  end

  def destroy
    if @resource_string.user_can_edit_original(@user) && @user.has_client_privileges?
      begin
        @resource_string.cleanup_and_refund
      rescue => e
        set_err(e.message)
        return
      end
      @resource_string.destroy
      @text_resource.update_version_num
      flash[:notice] = _('String deleted')
    else
      flash[:notice] = _('This string cannot be deleted right now')
    end

    redirect_to action: :index
  end

  def edit
    if @resource_string.duplicates.any?
      Rails.logger.info "Trying to edit a master string RS id ##{@resource_string.id}"
      @frozen_message = 'This string has duplicated strings linked to it, modification is not allowed. If you need to edit this string please contact support.'
    end

    @editing_original = true
    @edit_height = [[5, (@resource_string.txt.length / 30).to_i].max, 30].min
  end

  def update
    reload = false
    if (params[:req] == 'save') && params[:resource_string] && (params[:resource_string][:txt])
      if params[:resource_string][:txt] != @resource_string.txt
        return if @resource_string.duplicates.any?

        if params[:resource_string][:txt].count_words != @resource_string.txt.count_words
          @resource_string.cleanup_and_refund
        end

        @resource_string.update_attributes!(params[:resource_string])
        if params[:minor_change].blank?
          @resource_string.string_translations.each { |st| st.update_attributes(status: STRING_TRANSLATION_NEEDS_UPDATE) }
          reload = true
        end
        @text_resource.update_version_num
      end
    end
    @reload = reload
  end

  def edit_translation
    session[:next_in_progress_str_id] = params[:next_str] if params[:next_str]
    do_string_edit
  end

  def update_translation
    reload = false
    @warning = nil
    @next_string_to_edit = nil

    @string_translation.assign_attributes(params[:string_translation]) unless params[:req] == 'cancel'

    unless @string_translation.valid?
      @warning = list_errors(@string_translation.errors.full_messages, false)
      return
    end

    if params[:req] == 'save'

      if CharConversion.include_emoji? params[:string_translation][:txt]
        @warning = 'The string contains emojis. Unfortunatelly, they are not supported. Please remove all emojis and try again.'
        return
      end

      ok = true
      check_last = false

      complete_translation = (params[:complete_translation].to_i == 1)

      if complete_translation
        # --- check the required text ---
        orig_counts = @resource_string.count_required_text(@text_resource.required_text, @text_resource.check_standard_regex)
        translation_counts = @string_translation.count_required_text(@text_resource.required_text, @text_resource.check_standard_regex, params[:string_translation][:txt])

        # generate a list of all the keys
        all_keys = orig_counts.keys
        translation_counts.keys.each do |key|
          all_keys << key unless all_keys.include?(key)
        end

        # list of mismatched required text
        @count_mismatch = []

        all_keys.each do |word|
          if translation_counts[word] != orig_counts[word]
            @count_mismatch << [word, orig_counts[word] || 0, translation_counts[word] || 0]
          end
        end

        # if there's a mismatch, don't let complete
        if @count_mismatch.any?
          @warning = 'This string could not be completed because some required text does not match:<ul>'
          @warning  += (@count_mismatch.collect { |cm| "<li><b>#{h(cm[0])}</b> appears #{cm[1] == 1 ? 'once' : 'times'} in the original and #{cm[2] == 1 ? 'once' : 'times'} in the translation. If you think this is a valid translation, please ask client to remove this piece of text from <b>Required Text</b> in projects' settings page..</li>" }).join
          @warning  += '</ul>'

          complete_translation = false
        end

        if @string_translation.txt.blank?
          @warning = 'You have not provided any text into the translation box. Please complete translation in order to declare string as done.'
          complete_translation = false
        end

        # --- check for maximum length ---
        if @resource_string.max_width && params[:string_translation] && params[:string_translation][:txt]
          orig_length = @resource_string.txt.mb_chars.size
          translation_length = params[:string_translation][:txt].mb_chars.size
          if (translation_length * 100) > @resource_string.max_width * orig_length
            complete_translation = false
            @length_ratio = translation_length * 100.0 / orig_length

            @warning = _("The translation cannot be completed because it exceeds the maximum length.\n\nMaximum allowed: %d%s, actual length: %d%s\n(percentage of original length)") % [@resource_string.max_width.to_i, '%', @length_ratio.to_i, '%']
          end
        end
      end

      status = if complete_translation
                 STRING_TRANSLATION_COMPLETE
               else
                 if @user == @text_resource.client
                   STRING_TRANSLATION_NEEDS_UPDATE
                 else
                   STRING_TRANSLATION_BEING_TRANSLATED
                 end
               end

      # if this is the translator, locate the chat
      if complete_translation && (@string_translation.pay_translator == 1) && (@user[:type] == 'Translator')
        @resource_chat = @resource_language.resource_chats.where('(translator_id=?)', @user.id).first

        # this object has an optimistic lock. First, make sure we own it
        ok = @string_translation.update_attributes(pay_translator: 0)

        if ok
          paid = false

          # deposit money to the translator's account
          word_count = @text_resource.count_words([@resource_string], @text_resource.language, nil)
          amount_per_word = @user.private_translator? ? 0 : @resource_chat.translation_amount
          amount = word_count * amount_per_word

          if amount > 0
            if @user.private_translator?
              if @text_resource.client.id != 16
                from_account = @resource_language.find_or_create_account(DEFAULT_CURRENCY_ID)
                to_account = RootAccount.find_or_create
                money_transaction = MoneyTransactionProcessor.transfer_money(from_account, to_account, amount, DEFAULT_CURRENCY_ID, TRANSFER_PAYMENT_FOR_TA_RENTAL)
              end
            else
              from_account = @resource_language.find_or_create_account(DEFAULT_CURRENCY_ID)
              to_account = @user.find_or_create_account(DEFAULT_CURRENCY_ID)
              money_transaction = nil
              begin
                money_transaction = MoneyTransactionProcessor.transfer_money(from_account, to_account, amount, DEFAULT_CURRENCY_ID, TRANSFER_PAYMENT_FROM_RESOURCE_TRANSLATION, FEE_RATE, @text_resource.client.affiliate)
              rescue StandardError => e
                @message = e.message
                return
              end
            end

            if money_transaction
              money_transaction.owner = @string_translation
              money_transaction.save!

              paid = true
            else
              logger.info "------- can't pay. didn't manage to create a money_transaction"
            end
          else
            paid = true
          end

          if paid
            # count the translated words
            @resource_chat.word_count -= word_count
            @resource_chat.word_count = 0 if @resource_chat.word_count < 0
            @resource_chat.save

            # indicate that we need to check if this is the last translation to do
            check_last = true
          else
            @string_translation.update_attributes(pay_translator: 1)
            ok = false
            reload = true
          end

        else
          reload = true
        end

      end

      if ok
        @string_translation.last_editor = @user

        # if translation is complete, ask for review in two cases:
        # - Was not complete before
        # - Translation is updating
        if complete_translation && (@string_translation.review_status == REVIEW_AFTER_TRANSLATION)
          @string_translation.review_status = REVIEW_PENDING_ALREADY_FUNDED
        end

        StaleObjHandler.retry do
          @string_translation.update_attributes!(params[:string_translation].merge(status: status))
        end
        @resource_language.update_version_num

        # save completed translations in the translation memory
        @string_translation.add_to_tm if complete_translation

      end

      if ok && check_last && @resource_chat
        # now, check if this is the last string to translate in this language
        @translation_complete = @resource_chat.need_to_declare_as_complete

        if @translation_complete && (@resource_chat.word_count != 0)
          @resource_chat.update_attributes(word_count: 0)
        end
      end

      # check if we're going to edit the next string
      unless params[:auto_edit_next].blank?
        @next_string_to_edit = ResourceString.where(id: params[:next_resource_string_id].to_i).first
      end
    end

    @reload = reload
  end

  def complete_review
    if @resource_language.managed_work && (@resource_language.managed_work.active == MANAGED_WORK_ACTIVE) && (@resource_language.managed_work.translator == @user)

      # check if we need to pay
      ok = true

      if @string_translation.pay_reviewer == 1
        if @string_translation.update_attributes(pay_reviewer: 0)
          # deposit money to the translator's account
          from_account = @resource_language.find_or_create_account(DEFAULT_CURRENCY_ID)
          to_account = @user.find_or_create_account(DEFAULT_CURRENCY_ID)

          word_count = @text_resource.count_words([@resource_string], @text_resource.language, nil)
          amount = word_count * @resource_language.review_amount

          if amount > 0
            begin
              money_transaction = MoneyTransactionProcessor.transfer_money(from_account, to_account, amount, DEFAULT_CURRENCY_ID, TRANSFER_PAYMENT_FROM_RESOURCE_REVIEW, FEE_RATE, @text_resource.client.affiliate)
            rescue MoneyTransactionProcessor::NotEnoughFunds => e
              logger.error e.message
              @alert_msg = _('There is not enough money on escrow account to complete review. Please contact client.')
            end

            if money_transaction
              money_transaction.owner = @string_translation
              money_transaction.save!
            else
              logger.info "------- can't pay. didn't manage to create a money_transaction"
              ok = false
            end
          end
        else
          ok = false
        end

        @string_translation.update_attributes(pay_reviewer: 1) unless ok

      end

      if ok
        @string_translation.update_attributes(review_status: REVIEW_COMPLETED)
        @resource_language.update_version_num

        first_string_to_review = @text_resource.next_string(nil, [@string_translation.language_id], ['(string_translations.status IN (?)) AND (string_translations.review_status = ?)'], [[STRING_TRANSLATION_COMPLETE], REVIEW_PENDING_ALREADY_FUNDED])

        unless first_string_to_review
          @resource_language.managed_work.update_attributes(translation_status: MANAGED_WORK_COMPLETE)
          if @text_resource.contact.can_receive_emails?
            ReminderMailer.managed_work_complete(
              @text_resource.contact,
              @resource_language.managed_work,
              @string_translation.language,
              'software localization project - %s' % @text_resource.name, controller: :text_resources, action: :show, id: @text_resource.id
            ).deliver_now
          end

          # update the chat to indicate that review is complete
          resource_chat = @resource_language.selected_chat
          if resource_chat && (resource_chat.translation_status == RESOURCE_CHAT_TRANSLATION_COMPLETE)
            resource_chat.update_attributes!(translation_status: RESOURCE_CHAT_TRANSLATION_REVIEWED)
            refund_resource_language_leftover_credit(@resource_language)
          end

        end

      end

    end
  end

  def remove_master

    if @resource_string.user_can_edit_original(@user)
      @resource_string.master_string = nil
      @resource_string.save!
    else
      flash[:notice] = 'This operation cannot be done with the string is being translated'
    end

    redirect_to action: :show

    @text_resource.update_version_num
  end

  def edit_comment
    unless [@user, @user.master_account].include?(@text_resource.client)
      set_err('You cannot do this')
      return
    end

    if params[:req] == 'show'
      @editing_comment = true
    elsif (params[:req] == 'save') && params[:resource_string]
      @resource_string.update_attributes!(comment: params[:resource_string][:comment])
    end
  end

  def add_auto_comments
    strings = params[:strings]
    processed = 0
    strings.each do |string_key, string|
      kind = string[:kind]
      data = string[:data]
      string = ResourceString.find(string_key)
      comment = ''
      if kind == 'placeholders'
        data.each do |placeholder_key, placeholder_data|
          unless placeholder_data[:explanation] == 'dont_need_explanation' || set_auto_comment_for_explanation(placeholder_data).nil?
            comment += "#{placeholder_key.to_i}th placeholder: " + set_auto_comment_for_explanation(placeholder_data) + "\n"
          end
        end
      elsif kind == 'one_word'
        unless data[:explanation] == 'dont_need_explanation' || set_auto_comment_for_explanation(data).nil?
          comment = set_auto_comment_for_explanation(data)
        end
      else
        flash[:notice] = 'cannot identify kind of string.'
      end

      if %w(placeholders one_word).include? kind
        unless comment.blank?
          processed += 1 if string.update_attributes(comment: comment, unclear: false)
        end
      end
    end
    flash[:notice] = "#{processed} comments were saved"
    redirect_to :back
  rescue => e
    logger = Logger.new('log/auto_comments.log')
    logger.error "Error #{e.message} : #{e.inspect}"
    flash[:notice] = 'Something went wrong, Please try saving it again or contact us.'
    redirect_to :back
  end

  def edit_length_limit
    unless [@user, @user.master_account].include?(@text_resource.client)
      set_err('You cannot do this')
      return
    end

    warning = nil

    if params[:req] == 'show'
      @editing_length_limit = true
    elsif (params[:req] == 'save') && params[:resource_string]
      max_width = if params[:resource_string][:max_width].blank?
                    nil
                  else
                    params[:resource_string][:max_width].to_i
                  end
      unless @resource_string.update_attributes(max_width: max_width)
        warning = 'Translation lengh cannot be limited to less than 50% of the original length'
      end
    end
    @warning = warning
  end

  def set_display_instructions
    session[:hide_resource_string_instructions] = (params[:hide].blank? ? nil : true)
  end

  def delete_selected
    begin
      delete_ids = make_dict(params[:resource_string])
    rescue
      delete_ids = []
    end

    text_resources = []

    if @user.has_client_privileges?
      delete_list = ResourceString.where(id: delete_ids)
      to_destroy = delete_list.find_all do |resource_string|
        unless text_resources.include?(resource_string.text_resource)
          text_resources << resource_string.text_resource
        end
        resource_string.user_can_edit_original(@user)
      end

      begin
        to_destroy.each(&:cleanup_and_refund)
      rescue => e
        set_err(e.message)
        return
      end
      to_destroy.each(&:destroy)
    end

    text_resources.each(&:update_version_num)

    if request.referer
      redirect_to request.referer
    else
      redirect_to action: :index
    end
  end

  # This method is deprecated, the link to it appears on text_resource/show as Find Format mismatches
  def find_mismatching
    @languages = [@user, @user.master_account].include?(@text_resource.client) ? @text_resource.resource_languages.collect(&:language) : @edit_languages
    @resource_strings = []
    @text_resource.resource_strings.joins(:string_translations).all.each do |resource_string|
      @resource_strings << resource_string if is_utf_16?(resource_string.txt)
    end
  end

  # This method is deprecated, Is the POST action after find_mismatching method is executed.
  def convert_selected
    begin
      convert_list = make_dict(params[:resource_string])
    rescue
      convert_list = []
    end

    @text_resource.resource_strings.joins(:string_translations).where('resource_strings.id IN (?)', convert_list).each do |resource_string|

      logger.info "--------- checking string #{resource_string.id}"

      resource_string.string_translations.each do |string_translation|
        logger.info "------- checking translation.#{string_translation.id}"
        utf8_txt = if string_translation.txt.length.odd?
                     unencode_string(string_translation.txt, ENCODING_UTF16_LE)
                   else
                     unencode_string(string_translation.txt[1..-1], ENCODING_UTF16_LE)
                   end
        logger.info "------ is_utf_16?(string_translation.txt)=#{is_utf_16?(string_translation.txt)}, !utf8_txt.blank?=#{!utf8_txt.blank?}"
        if is_utf_16?(string_translation.txt) && !utf8_txt.blank?
          string_translation.update_attributes!(txt: utf8_txt)
          logger.info '------- updated!'
        end
      end

      utf8_txt = if resource_string.txt.length.odd?
                   unencode_string(resource_string.txt, ENCODING_UTF16_LE)
                 else
                   unencode_string(resource_string.txt[1..-1], ENCODING_UTF16_LE)
                 end
      logger.info "------ is_utf_16?(resource_string.txt)=#{is_utf_16?(resource_string.txt)}, !utf8_txt.blank?=#{!utf8_txt.blank?}"
      if is_utf_16?(resource_string.txt) && !utf8_txt.blank?
        resource_string.update_attributes!(txt: utf8_txt)
        logger.info '------- updated!'
      end

    end

    @text_resource.update_version_num
    flash[:notice] = 'The selected strings were converted from UTF16 to UTF8'
    redirect_to controller: :text_resources, action: :show, id: @text_resource.id

  end

  private

  def locate_parent
    begin
      @text_resource = TextResource.find(params[:text_resource_id].to_i)
    rescue
      set_err('Cannot locate this project')
      return false
    end

    @managed_resource_languages = @text_resource.managed_works(@user)
    @edit_languages = @text_resource.translator_edit_languages(@user)

    if (@user[:type] == 'Translator') && !@edit_languages.empty?
      set_glossary_edit(@text_resource.client, @text_resource.language, @edit_languages)
    elsif [@user, @user.master_account].include?(@text_resource.client) || @user.has_supporter_privileges?
      set_glossary_edit(@text_resource.client, @text_resource.language, @text_resource.resource_languages.collect(&:language))
    else
      set_err('Not your project')
      return false
    end
  end

  def locate_string
    begin
      @resource_string = ResourceString.find(params[:id].to_i)
    rescue
      set_err('Cannot find this string')
      return false
    end

    if @resource_string.text_resource != @text_resource
      set_err('This string does not belong to the project')
      return false
    end
  end

  def locate_translation

    @resource_language = @text_resource.resource_languages.where('language_id=?', params[:lang_id].to_i).first
    unless @resource_language
      set_err('not translating to this language')
      return false
    end

    @string_translation = @resource_string.string_translations.where('language_id=?', params[:lang_id].to_i).first

    if !@string_translation
      @string_translation = StringTranslation.new(txt: @resource_string.txt)
      @string_translation.resource_string = @resource_string
      @string_translation.language = @resource_language.language
      @select_translation = true
    elsif (@string_translation.status == STRING_TRANSLATION_MISSING) || @string_translation.txt.blank?
      @string_translation.txt = @resource_string.txt
      @select_translation = true
    end

    true
  end

  def verify_client
    unless @user.has_client_privileges? || @user.has_supporter_privileges?
      set_err('You cannot do this')
      false
    end
  end

  def do_string_edit
    @editing = true
    @next_in_progress_str ||= ResourceString.where(id: session[:next_in_progress_str_id]).first
    @can_edit_next = ((@user[:type] == 'Translator') && @next_in_progress_str && (@edit_languages.length == 1)) && @next_in_progress_str.id != @resource_string.id
    @edit_height = [[5, (@resource_string.txt.length / 30).to_i].max, 30].min
  end

  def prepare_filter_conditions
    string_translations_status_list =
      if @status == 2
        [STRING_TRANSLATION_COMPLETE]
      elsif @status == 1
        [STRING_TRANSLATION_NEEDS_UPDATE, STRING_TRANSLATION_BEING_TRANSLATED, STRING_TRANSLATION_MISSING]
      else
        [STRING_TRANSLATION_COMPLETE, STRING_TRANSLATION_NEEDS_UPDATE, STRING_TRANSLATION_BEING_TRANSLATED, STRING_TRANSLATION_MISSING, STRING_TRANSLATION_DUPLICATE]
      end
    conds = []
    cond_args = []

    if @exclude_duplicates
      conds << '(resource_strings.master_string_id IS ?)'
      cond_args << nil
    end

    if @file && @file != '0'
      if @exact_match
        conds << '(resource_strings.context = ?)'
        cond_args << @file
      else
        conds << '(resource_strings.context LIKE ?)'
        cond_args << ('%' + @file + '%')
      end
    end

    if @token
      if @exact_match
        conds << '(resource_strings.token = ?)'
        cond_args << @token
      else
        conds << '(resource_strings.token LIKE ?)'
        cond_args << ('%' + @token + '%')
      end
    end

    if @txt
      if @exact_match
        conds << '(resource_strings.txt = ?)'
        cond_args << @txt
      else
        conds << '(resource_strings.txt LIKE ?)'
        cond_args << ('%' + @txt + '%')
      end
    end

    if @translation
      if @exact_match
        conds << '(string_translations.txt = ?)'
        cond_args << @translation
      else
        conds << '(string_translations.txt LIKE ?)'
        cond_args << ('%' + @translation + '%')
      end
    end

    filter_by_language = ''
    if @user[:type] == 'Translator'
      languages_ids = @languages.map(&:id).join(',')
      filter_by_language = "AND string_translations.language_id IN (#{languages_ids})"
    end

    if @status == 2 # String Completed
      conds << "(NOT EXISTS (SELECT * FROM string_translations WHERE STATUS != ? #{filter_by_language} AND string_translations.resource_string_id = resource_strings.id))"
      cond_args << STRING_TRANSLATION_COMPLETE
    elsif @status == 1 # Untranslated strings
      conds << "(EXISTS
        (SELECT * FROM string_translations, resource_languages WHERE string_translations.status IN (?)
            AND string_translations.resource_string_id = resource_strings.id
            AND string_translations.language_id = resource_languages.language_id
            #{filter_by_language}
            AND resource_languages.text_resource_id = resource_strings.text_resource_id
            AND resource_strings.master_string_id IS NULL
        ))"
      cond_args << [STRING_TRANSLATION_NEEDS_UPDATE, STRING_TRANSLATION_BEING_TRANSLATED, STRING_TRANSLATION_MISSING]
    end

    if @size_ratio
      if @size_ratio == 'user'
        conds << '(resource_strings.max_width IS NOT NULL) AND ((string_translations.size_ratio * 100) >= resource_strings.max_width)'
      else
        @low_ratio = @size_ratio.to_f / 100.0
        @high_ratio = @size_ratio.to_f / 100.0 + 0.1
        conds << '(string_translations.size_ratio >= ?) AND (string_translations.size_ratio < ?)'
        cond_args << @low_ratio
        cond_args << @high_ratio
      end
    end

    [conds, cond_args]
  end

  def get_filter_from_session
    @file = session[:file]
    @token = session[:token]
    @txt = session[:txt]
    @exact_match = session[:exact_match] || false
    @exclude_duplicates = session[:exclude_duplicates] || false
    @translation = session[:translation]
    @status = session[:status] || 0
    @size_ratio = session[:size_ratio]
    @per_page = session[:per_page] || 20
  end

  def set_auto_comment_for_explanation(parameters)
    case parameters['explanation']
    when 'verb'
      'This is a verb.'
    when 'noun'
      'This is a noun.'
    when 'article'
      'This is an article.'
    when 'more_explanation'
      parameters['more_explanation']
    end
  end
end
