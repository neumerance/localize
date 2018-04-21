# This is deprecated and obsolete

class WebDialogsController < ApplicationController
  prepend_before_action :setup_user_optional, except: [:new, :create, :gen_captcha]
  before_action :locate_dialog, only: [:show, :create_message, :close_ticket, :attachment, :update, :delete]
  before_action :locate_message, only: [:decide_about_translation, :show_self_translation, :set_translation, :show_translation]
  before_action :setup_display_language, except: [:gen_captcha, :new, :create, :attachment]
  before_action :verify_supporter, only: [:index, :pending, :my, :all, :close_ticket, :update]
  before_action :verify_client, only: [:update, :delete]
  layout :determine_layout

  def new
    redirect_to 'https://icanlocalize.com'

    # session[:captcha_passed] = nil
    #
    # begin
    #   language = Language.find(params[:language_id])
    # rescue
    #   set_err('Cannot find this language')
    #   return
    # end
    #
    # set_locale_by_language(language)
    #
    # return false unless setup_for_new
    #
    # @web_dialog = WebDialog.new
    # @web_dialog.visitor_language_id = language.id
    #
    # department_id = params[:department].to_i
    # if department_id != 0
    #   begin
    #     department = @web_support.client_departments.find(department_id)
    #     @web_dialog.client_department = department
    #   rescue
    #     set_err('Cannot find this department')
    #     return
    #   end
    # elsif @web_support.client_departments.count == 1
    #   @web_dialog.client_department = @web_support.client_departments[0]
    # elsif @web_support.client_departments.count == 0
    #   set_err('This support center is not fully set up yet')
    #   return
    # end
  end

  def gen_captcha
    ok = false
    if !params[:client].blank? && !params[:key].blank? && !params[:rand].blank?
      client_id = params[:client].to_i
      if params[:key] == Digest::MD5.hexdigest(client_id.to_s + CAPTCHA_RAND)
        captcha_image = CaptchaImage.new(content_type: 'image/jpeg', filename: 'captcha.jpg')
        if captcha_image.generate_image(params[:rand].to_i, client_id)
          ok = captcha_image.save
          # logger.info "-----------> Generated image:#{captcha_image.id}. Code=#{captcha_image.code}, client_id=#{client_id}, rand=#{params[:rand].to_i}"
        end
      end
    end

    if ok
      send_file(captcha_image.full_filename, type: 'image/jpeg', disposition: 'inline')
    else
      render(text: 'ERROR')
    end

  end

  def create
    @web_dialog = WebDialog.new(params[:web_dialog])
    @web_dialog.create_time = Time.now
    @web_dialog.status = SUPPORT_TICKET_CREATED
    @web_dialog.translation_status = TRANSLATION_NEEDED
    @web_dialog.accesskey = rand(10000)

    # the locale can be set even if there is a problem with the branding or other parameters
    set_locale_by_language(@web_dialog.visitor_language)

    begin
      @web_support = WebSupport.find(params[:store].to_i)
    rescue
      @web_support = nil
    end

    if @web_support
      setup_branding_for_language(@web_support, @web_dialog.visitor_language_id)
    end

    # set up the user parameters from either the user's input or from the session
    if params[:user_params]
      params_list = params[:user_params]
      params_values = params
    elsif session[:params_list]
      params_list = session[:params_list]
      params_values = session[:params_values] || {}
    else
      params_list = nil
      params_values = {}
    end

    captcha_image = nil
    if session[:captcha_passed]
      @captcha_passed = true
    elsif !params[:rand].blank? && @web_support
      captcha_image = CaptchaImage.where('(client_id=?) AND (user_rand=?)', @web_support.client_id, params[:rand].to_i).first
    elsif !params[:captcha_id].blank?
      begin
        captcha_image = CaptchaImage.find(params[:captcha_id].to_i)
      rescue
      end
    end

    # check the captcha code
    if @captcha_passed
      ok = true
    elsif captcha_image && (params[:code] == captcha_image.code)
      @captcha_passed = true
      ok = true
    else
      logger.info ' -------- bad captcha code'
      ok = false
      @captcha_error = true
      @web_dialog.errors.add(:base, _("Verification code doesn't match"))
    end

    if ok && @web_dialog.save
      # create the first message in this ticket
      message = WebMessage.new(client_body: @web_dialog.message,
                               visitor_body: @web_dialog.message,
                               create_time: Time.now,
                               notified: 0,
                               comment: 'This message is part of a support ticket')
      message.associate_with_dialog(@web_dialog, @web_dialog.message)

      # look for user supplied parameters
      unless params_list.blank?
        params_list.split.each do |param|
          next if params_values[param].blank?
          dialog_parameter = DialogParameter.new(name: param, value: params_values[param])
          dialog_parameter.web_dialog = @web_dialog
          dialog_parameter.save!
        end
      end

      if @web_dialog.can_receive_emails?
        InstantMessageMailer.confirm(@web_dialog, @web_dialog.visitor_language).deliver_now
      end
      notify_client_about_new_message(@web_dialog, message)
      @header = _('Your message has been sent')
    else
      if params[:user_params]
        session[:params_list] = params[:user_params]

        save_user_params = {}
        params[:user_params].split.each do |param|
          save_user_params[param] = params[param] unless params[param].blank?
        end
        session[:params_values] = save_user_params
      end

      return false unless setup_for_new
      render action: :new
    end
  end

  def show
    set_locale_by_language(@web_dialog.visitor_language) unless @user

    session[:web_dialog_id] = @web_dialog.id

    @reply_heading = if @web_dialog.available_web_messages_for_user(@user)[-1].user == @user
                       _('Add another message')
                     else
                       _('Reply')
                     end

    if @user
      @parameters = @web_dialog.dialog_parameters.collect { |param| [param.name, param.value] }
      @google_translation_api = (Rails.env != 'development') && (@web_dialog.visitor_language_id != @web_dialog.client_department.language_id)
    end

    @username = @web_dialog.full_name
    @header = _('Support ticket: %s') % @web_dialog.subject_for_user(@user)

    @dialog_info = [[_('Name'), @username],
                    [_('E-Mail'), @web_dialog.email],
                    [_('Created'), @web_dialog.create_time.strftime(TIME_FORMAT_STRING)],
                    [_('Status'), @web_dialog.show_status]]
    unless @user
      setup_branding_for_language(@web_dialog.client_department.web_support, @web_dialog.visitor_language_id)
    end

    # set up previous and next navigation
    @ticket_nav = []
    if @user
      prev_open = @web_dialog.client_department.web_support.web_dialogs
      where("(web_dialogs.status IN (#{[SUPPORT_TICKET_CREATED, SUPPORT_TICKET_WAITING_REPLY].join(',')})) AND (web_dialogs.id < #{@web_dialog.id})").
        order('web_dialogs.id DESC')
      first
      next_open = @web_dialog.client_department.web_support.web_dialogs
      where("(web_dialogs.status IN (#{[SUPPORT_TICKET_CREATED, SUPPORT_TICKET_WAITING_REPLY].join(',')})) AND (web_dialogs.id > #{@web_dialog.id})").
        first
      @ticket_nav << [_('Previous open ticket'), prev_open.id] if prev_open
      @ticket_nav << [_('Next open ticket'), next_open.id] if next_open

      @languages = Language.list_major_first
    end

  end

  def update
    @web_dialog.update_attributes(params[:web_dialog])
    flash[:notice] = 'Updated ticket language'
    redirect_to action: :show
  end

  def delete
    id = @web_dialog.client_department.web_support.id
    @web_dialog.destroy
    flash[:notice] = _('Ticket deleted')
    redirect_to controller: :web_supports, action: :show, id: id
  end

  def attachment
    begin
      attachment = WebAttachment.find(params[:attachment_id])
    rescue
      set_err('Cannot find attachment')
      return
    end
    if attachment.web_message.owner != @web_dialog
      set_err("attachment doesn't belong to this ticket")
      return
    end
    send_file(attachment.full_filename)
  end

  def create_message
    if @orig_user
      flash[:notice] = "you can't post a message while logged in as other user"
      redirect_to :back
      return
    end
    warnings = []
    if @web_dialog && (session[:web_dialog_id] == @web_dialog.id)

      # never translate if coming and going to the same language
      translation_status = if @web_dialog.visitor_language_id == @web_dialog.client_department.language_id
                             TRANSLATION_NOT_NEEDED
                           else
                             params[:translation_status].to_i
                           end

      body = params[:body]
      warnings << _('No message entered') if body.blank?
      if @is_client && (translation_status != TRANSLATION_NEEDED) && (translation_status != TRANSLATION_NOT_NEEDED)
        warnings << _('Now you must select if the message needs translation')
      end

      if warnings.empty?
        whereto = if @user
                    :client_body
                  else
                    :visitor_body
                  end

        message = WebMessage.new(whereto => body,
                                 :translation_status => translation_status,
                                 :create_time => Time.now,
                                 :notified => 0,
                                 :comment => 'This message is part of a support ticket')
        message.user = @user if @user
        message.associate_with_dialog(@web_dialog, body)

        create_attachments_for_message(message)

        confirmation = _('Your message was sent.')

        # if there's a logged in user - it's the supporter
        if @user
          if params[:leave_open].blank?
            @web_dialog.update_attributes!(status: SUPPORT_TICKET_ANSWERED)
          end
        elsif @web_dialog.status != SUPPORT_TICKET_CREATED
          @web_dialog.update_attributes!(status: SUPPORT_TICKET_WAITING_REPLY)
        end

        # send the new message notification
        if !@user
          notify_client_about_new_message(@web_dialog, message)
        elsif message.translation_status == TRANSLATION_NOT_NEEDED
          set_locale_for_lang(@web_dialog.visitor_language)
          if @web_dialog.can_receive_emails?
            InstantMessageMailer.notify_visitor(@web_dialog, message, @web_dialog.visitor_language).deliver_now
          end
          set_locale(@locale)
        end

      end
    end
    if !warnings.empty?
      @warning = warnings.collect { |w| "- #{w}." }.join("\n")
    else
      flash[:ack] = _('Your message was sent!')
    end
    respond_to do |f|
      f.html { request.referer ? (redirect_to :back) : (render plain: 'ok') }
      f.js
    end
  end

  def close_ticket
    unless @web_dialog.user_can_close?(@user)
      set_err('cannot close this ticket')
      return
    end
    @web_dialog.update_attributes!(status: SUPPORT_TICKET_SOLVED)

    redirect_to action: :show, id: @web_dialog.id
  end

  def decide_about_translation
    unless params[:translate].blank?
      translate = params[:translate].to_i
      if @web_message.update_attributes(translation_status: translate)
        if @user && (translate == TRANSLATION_NOT_NEEDED)
          set_locale_for_lang(@web_dialog.visitor_language)
          if @web_dialog.can_receive_emails?
            InstantMessageMailer.notify_visitor(@web_dialog, @web_message, @web_dialog.visitor_language).deliver_now
          end
          set_locale(@locale)
        end
      end
    end
  end

  def show_self_translation
    if @web_message.client_body.blank? && @web_message.visitor_language.google_language && @web_message.client_language.google_language
      @text_to_translate = @web_message.decoded_visitor_body(@user).delete("\r").tr("\n", ' ')
      @orig_language = @web_message.visitor_language.google_language.code
      @dest_language = @web_message.client_language.google_language.code
      @set_google_translation = true
      # logger.info "--------- @orig_language: #{@orig_language}, @dest_language: #{@dest_language}\n@text_to_translate: #{@text_to_translate}"
    end
  end

  def show_translation; end

  def set_translation
    @web_message.client_body = params[:web_message][:client_body]
    @web_message.translation_status = TRANSLATION_COMPLETE
    @web_message.save!
  end

  private

  def setup_for_new
    begin
      @web_support = WebSupport.find(params[:store].to_i)
    rescue
      set_err('Cannot find this web support')
      return false
    end

    @client = @web_support.client
    @client_departments = @web_support.client_departments

    @header = _('Contact %s') % @web_support.name

    setup_captch_image

    # ---------- set up the branding ------------
    setup_branding_for_language(@web_support, params[:language_id])

    true
  end

  def setup_branding_for_language(web_support, language_id)
    return if @branding
    conds = { 'language_id' => language_id }
    @branding = web_support.brandings.where(conds).first
    @branding = web_support.brandings.first unless @branding
    if @branding
      # logger.info "-------- protocol #{request.protocol}"
      @logo_url = @branding.logo_url
      if request.protocol[0...5] == 'http:'
        @logo_url = @logo_url.gsub('https:', 'http:')
        # logger.info "--------- changed logo URL to: #{@logo_url}"
      end
      @logo_size = "#{@branding.logo_width}x#{@branding.logo_height}"
      @logo_title = _('Back to %s') % web_support.name
      @home_url = @branding.home_url
    end
  end

  def setup_captch_image
    if @captcha_passed
      session[:captcha_passed] = true
    else
      @captcha_image = CaptchaImage.new(content_type: 'image/jpeg', filename: 'captcha.jpg')
      @captcha_image.generate_image
    end
  end

  def setup_user_optional
    setup_user(false) if params[:accesskey].nil?

    @wait_with_locale = true unless @user

    if session[:loc_code]
      set_locale(session[:loc_code])
      @locale = session[:loc_code]
    end

  end

  def verify_supporter
    unless @user
      set_err('You cannot do this')
      false
    end
  end

  def locate_dialog
    begin
      @web_dialog = WebDialog.find(params[:id].to_i)
    rescue
      set_err('cannot locate this dialog')
      return false
    end
    verify_dialog_ownership(true)
  end

  def locate_message
    begin
      @web_message = WebMessage.find(params[:id].to_i)
    rescue
      set_err('cannot locate this message')
      return false
    end
    @web_dialog = @web_message.owner
    verify_dialog_ownership(false)
  end

  def setup_display_language
    @display_language = @user ? @web_dialog.client_department.language : @web_dialog.visitor_language
  end

  def verify_dialog_ownership(allow_visitor)
    @is_client = @user && (@user == @web_dialog.client_department.web_support.client)
    if @is_client || (allow_visitor && (@web_dialog.accesskey == params[:accesskey].to_i)) || (@user && @user.has_supporter_privileges?)
      return true
    elsif !@user
      session[:last_url] = [request.url]
      session[:go_to_last_url] = true
      set_err(_('The page you accessed required logging in. Please log in to your account first.'), NOT_LOGGED_IN_ERROR)
      return false
    else
      set_err(_('You cannot access this dialog'))
      return false
    end
  end

  def verify_client
    unless @user && (@user == @web_dialog.client_department.web_support.client)
      set_err('You cannot do this')
      false
    end
  end

  def set_locale_by_language(language)
    return unless language
    selected_locale = if LOCALES.key?(language.name)
                        LOCALES[language.name]
                      else
                        DEFAULT_LOCALE
                      end
    set_locale(selected_locale)
    @locale = selected_locale
    session[:loc_code] = selected_locale
  end

  def notify_client_about_new_message(web_dialog, message)
    deliver = false
    not_enough_money = false
    if [TRANSLATION_NOT_NEEDED, TRANSLATION_PENDING_CLIENT_REVIEW].include?(message.translation_status)
      deliver = true
    elsif (message.translation_status == TRANSLATION_NEEDED) && !message.has_enough_money_for_translation?
      deliver = true
      not_enough_money = true
    end
    if deliver
      set_locale_for_lang(web_dialog.client_department.language)
      if web_dialog.client_department.web_support.client.can_receive_emails?
        InstantMessageMailer.notify_client(web_dialog, message, not_enough_money).deliver_now
      end
      set_locale(@locale)
    end
  end

  def create_attachments_for_message(web_message)
    attachment_id = 1
    cont = true
    while cont
      attached_data = params["file#{attachment_id}"]
      if !attached_data.blank? && !attached_data[:uploaded_data].blank?
        attachment = WebAttachment.new(attached_data)
        attachment.web_message = web_message
        attachment.save
        attachment_id += 1
      else
        cont = false
      end
    end
  end

end
