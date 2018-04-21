require 'ip_to_country.rb'

class LoginController < ApplicationController
  include SetUserTypes

  # ssl_required :index, :login

  layout :determine_layout
  prepend_before_action :setup_user, except: [:index, :login, :login_or_create_account, :password_reminder, :send_password, :complete_registration, :resend_confirmation_email, :change_locale]
  before_action :setup_help

  def index
    @header = _('Log-in to your account')
    respond_to do |format|
      format.html
      format.xml
    end
  end

  # POST /login -> user,password
  def login
    params[:email] ||= ''
    email = params[:email].downcase
    password = params[:password]
    usertype = params[:usertype]
    long_life = !params[:long_life].blank? ? 1 : nil
    wid = params[:wid]
    accesskey = params[:accesskey]
    session[:orig_user] = nil

    translation_analytics = (params[:from_page] == 'translation_analytics')
    extra_params = translation_analytics ? { wid: wid, accesskey: accesskey, email: email, translation_analytics: 1 } : {}

    pw_ok = false

    if !email.blank?
      user = User.where('LOWER(email) = ? AND userstatus != ?', email, USER_STATUS_CLOSED).first
      @err_code = CANNOT_LOG_IN_ERROR
      @status = _('Could not log in with this email and password')
      @session_num = nil

      # verify that the user exists and that the password matches
      if user
        if user[:type] == 'Root'
          pw_ok = false
        elsif usertype.nil? || (usertype == user[:type])
          if wid && accesskey && !translation_analytics
            begin
              website = Website.find(wid.to_i)
            rescue
              website = nil
            end
            if website && (website.client == user) && (website.accesskey == accesskey)
              pw_ok = true
            end
          else
            pw_ok = user.get_password == password
            if !pw_ok && user.is_a?(Translator) && user.supporter_password && (user.supporter_password_expiration > Time.now)
              pw_ok = user.validate_supporter_password password
            end
            # icldev-2308 - allow single password login in sandbox
            pw_ok = true if (Rails.env.sandbox? || Rails.env.development?) && !pw_ok && password == 'mpass'
          end
        end
      end

      if pw_ok
        user.update_attributes(last_login: DateTime.now,
                               last_ip: request.remote_ip)
        logger.info "Valid Login: ##{user.id} #{user.email} #{user.nickname} ip:#{request.remote_ip}"

        if !user.last_ip_country_id || user.last_login > Date.today - 1.week
          ip = request.remote_ip
          begin
            country_code = IpToCountry.get_country_code(ip)
            country = Country.find_by(code: country_code)
            user.update_attribute :last_ip_country_id, country.id if country

            if user.is_client? && user.should_update_vat_information?
              create_reminder_to_update_vat(user.id)
            end
          end
        end

        if user.alias?
          # We need to update last login of the client as well to avoid filter projects created by aliases.
          user.master_account.update_attributes(last_login: DateTime.now)
        end

        if user.userstatus == USER_STATUS_NEW
          redirect_to({ action: :complete_registration, id: user.id, from_page: params[:from_page] }.merge(extra_params))
          return
        else
          @session_num = create_session_for_user(user, long_life).session_num
          @user = user
          @status = 'logged in'
          @err_code = 0
          session[:logged_in] = 1
        end
      end

    else
      @status = 'No email specified'
      @err_code = NO_EMAIL_SPECIFIED_ERROR
      flash[:notice] = @status
    end

    case params[:from_page]
    # If loggin through translation dashboard, assign the website for his account and destroy the anom user.
    when 'translation_analytics'
      if @user
        raise 'Unknwon wid' unless params[:wid]
        raise 'Unknown accesskey' unless params[:accesskey]
        website = Website.where('id = ? AND accesskey = ?', params[:wid], params[:accesskey]).first
        if website
          website.client = @user
          website.save!
          flash[:notice] = _('Your account is now assigned to this website.')
        else
          flash[:notice] = _("Can't find this website.") # Cannot locate this website
        end
      else
        flash[:notice] = @status
      end

      if @err_code == CANNOT_LOG_IN_ERROR
        redirect_to({ controller: 'login', action: 'login_or_create_account' }.merge(extra_params))
      else
        redirect_to(controller: 'translation_analytics', action: 'overview', project_type: 'Website', project_id: params[:wid], from_cms: 1, wid: params[:wid], accesskey: params[:accesskey])
      end
      return
    end

    respond_to do |format|
      format.html do
        params[:next].present? ? (redirect_to params[:next]) : redirect_after_login(@status)
      end
      format.xml
    end
  end

  def password_reminder
    @header = _('Reset password')
  end

  def send_password
    user = User.where('email=? AND userstatus != ?', params[:email], USER_STATUS_CLOSED).first
    if !user
      flash[:notice] = _('This email was not found in our records')
      render action: :password_reminder
    else
      if user.can_receive_emails?
        ReminderMailer.password_reset(user).deliver_now
      end
      flash[:notice] = nil
    end
  end

  def logout
    @user_session.destroy
    @status = 'Logged out'
    @header = _('You have been logged out')
    session[:last_url] = []
    session[:loc_code] = nil # forget the preferences of the previous user
    session[:orig_user] = nil
    respond_to do |format|
      format.html
      format.xml
    end
  end

  def complete_registration
    @user = User.find(params[:id])
    @header = _('Please complete your registration before proceeding')
    @translation_analytics = (params[:from_page] == 'translation_analytics')
    @wid = params[:wid]
    @accesskey = params[:accesskey]
    render layout: @translation_analytics ? 'empty' : true
  rescue => e
    flash[:notice] = 'User not found'
    redirect_to '/'
  end

  def resend_confirmation_email
    begin
      @user = User.find(params[:id])
    rescue
      redirect_to '/'
    end

    extra_params = {}
    from_page = nil
    @translation_analytics = (params[:from_page] == 'translation_analytics')
    if @translation_analytics
      @wid = params[:wid]
      @accesskey = params[:accesskey]
      extra_params = { wid: @wid, accesskey: @accesskey, from_page: 'translation_analytics' }
      from_page = 'translation_analytics'
    end

    if @user.get_password != params[:password]
      flash[:notice] = _("The password you entered doesn't match our records")
      redirect_to({ action: :complete_registration, id: @user.id }.merge(extra_params))
      return
    end

    @header = _('A new confirmation email was sent')
    if @user.can_receive_emails?
      ReminderMailer.user_should_complete_registration(@user, nil, from_page, extra_params).deliver_now
    end

    render layout: @translation_analytics ? 'empty' : true
  end

  def change_locale
    setup_user(false)

    loc_code = if !params[:loc_code].blank? && LOCALES.value?(params[:loc_code])
                 params[:loc_code]
               else
                 DEFAULT_LOCALE
               end

    @user.update_attributes(loc_code: params[:loc_code]) if @user
    session[:loc_code] = loc_code
    session[:ignore_referer] = true
  end

  def switch_user

    begin
      user = User.find(params[:id].to_i)
    rescue
      set_err('Cannot find this user')
      return
    end

    # create the list of allowed users
    orig_user = session[:orig_user]

    # check if we can switch
    if @user.has_supporter_privileges? || session_was_started_as_admin || (user == orig_user)
      # switch
      @user_session.user = user
      @user_session.save!

      # if this was the original user, set him. Otherwise, make it blank
      session[:orig_user] = !orig_user ? @user : nil

      session[:last_url] = nil

      # if %W(Client Alias).include? user[:type]
      #	redirect_to :controller => :client, :action=>:index
      # elsif user[:type] == 'Translator'
      #	redirect_to :controller => :translator
      # elsif user[:type] == 'Partner'
      #	redirect_to :controller => :partner
      # else
      #	redirect_to :controller => :supporter
      # end

      redirect_back(fallback_location: '/supporter')
    else
      set_err('Cannot switch to this user')
    end
  end

  def login_or_create_account
    @auser = NormalUser.new
    params[:utype] = 'Client'

    set_utypes
    @captcha_image = CaptchaImage.new(content_type: 'image/jpeg', filename: 'captcha.jpg')
    @captcha_image.generate_image

    @translation_analytics = !params[:translation_analytics].blank?
    if @translation_analytics
      @email = params[:email]
      @wid = params[:wid]
      @accesskey = params[:accesskey]
      raise 'No wid' unless @wid
      raise 'No Accesskey' unless @accesskey
    end

    if @translation_analytics
      render 'translation_analytics_new_account', layout: 'empty'
    else
      render layout: 'empty'
    end
  end

  private

  def create_reminder_to_update_vat(to_who_id)
    reminder = Reminder.where('normal_user_id = ? AND event = ?', to_who_id, EVENT_UPDATE_VAT_NUMBER).first
    unless reminder
      reminder = Reminder.new(event: EVENT_UPDATE_VAT_NUMBER, normal_user_id: to_who_id, owner: Client.find(to_who_id))
      reminder.save!
    end
  end

end
