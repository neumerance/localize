class UsersController < ApplicationController
  include ::ProcessorLinks
  include ::CreateDeposit

  include ::SetUserTypes
  include ::UpdateSupporterDataAction

  include ::Users::UserSource
  include ::Users::WelcomeMail

  prepend_before_action :setup_user, except: [:translation_analytics_welcome, :new, :create, :validate, :reset_password, :resend_activation_email]
  layout :determine_layout
  before_action :verify_admin, only: [:edit, :update, :admins, :toggle_admin_notifications]
  before_action :verify_supporter, only: [:index, :find, :find_results, :list_translation_languages, :bilinguals, :top, :clients_by_source, :manage_works, :web_messages_list]
  before_action :verify_ownership, except: [:translation_analytics_welcome, :update_supporter_data, :index, :find, :find_results,
                                            :new, :create, :validate,
                                            :my_profile, :update_password, :request_practice_project, :setup_practice_project,
                                            :list_translation_languages,
                                            :update_translation_language_results,
                                            :bilinguals,
                                            :reset_password, :admins, :toggle_admin_notifications,
                                            :top, :clients_by_source, :signup, :update_name_and_email, :resend_activation_email,
                                            :update_display_settings, :complete_sandbox, :remove_compact_display_session]
  before_action :create_reminders_list
  before_action :setup_help, only: [:my_profile]
  before_action :set_utypes, only: [:new, :create]
  before_action :setup_captch_image, only: [:new, :create]

  def translation_analytics_welcome
    render layout: 'empty'
  end

  # GET /users
  # GET /users.xml

  def index
    @header = 'All users in the system'
    keyword = params[:keyword].present? ? params[:keyword].downcase.strip : nil
    type = params[:type].present? && params[:type] != 'Root' ? params[:type].strip : nil
    created_at = params[:created_at].present? ? params[:created_at].strip : nil

    where = type.nil? ? ["((type != 'Root')", '(anon != 1))'] : ["((type = '#{type}')", '(anon != 1))']
    where << (created_at.nil? ? ' 1 = 1 ' : " (created_at > '#{created_at} 00:00:00') ")
    where << "(LOWER(fname) LIKE \"#{keyword}%\" OR LOWER(lname) LIKE \"#{keyword}%\" OR LOWER(email) LIKE \"#{keyword}%\" OR LOWER(nickname) LIKE \"#{keyword}%\")" unless keyword.nil? || keyword.blank?
    @pager = ::Paginator.new(User.where(where.join(' AND ')).count, PER_PAGE) do |offset, per_page|
      User.where(where.join('AND')).order('id ASC').limit(per_page).offset(offset)
    end
    @users_page = @pager.page(params[:page])
    @list_of_pages = (1..@pager.number_of_pages).to_a
    @show_number_of_pages = (@pager.number_of_pages > 1)

    render action: :users_list
  end

  def find
    @header = 'Find a user'
  end

  def manage_aliases
    @header = _('Alias Management')
    @aliases = @auser.aliases
  end

  def find_results
    @header = 'Search results'
    fields = params[:keywords].reject { |k, v| v.blank? }

    unless fields.values.blank?
      conditions = []
      fields.each do |k, v|
        conditions << if k.to_s == 'email'
                        "LOWER(#{k.to_s}) LIKE \"%#{v.to_s.downcase.strip}%\""
                      else
                        "LOWER(#{k.to_s}) LIKE \"#{v.to_s.downcase.strip}%\""
                      end
      end

      conditions = conditions.join(' AND ')
      @users_page = User.where(conditions)
      render action: :users_list
    else
      redirect_to url_for(action: :find) if fields.values.blank?
    end
  end

  def list_translation_languages
    @header = 'Show translation languages'
    @source_languages = Language.list_major_first
    @target_languages = Language.list_major_first
  end

  def bilinguals
    @header = 'Translators with more than one target language'
    @users_page = []
    Translator.where(userstatus: USER_STATUS_QUALIFIED).each do |translator|
      @users_page << translator if translator.to_languages.length > 1
    end
    render action: :users_list
  end

  def update_tool
    unless (@user == @auser) || @user.has_supporter_privileges?
      raise 'Operation not permited'
    end

    tool = params[:tool]
    tool_id = params[:tool_id]
    value = params[:value]

    if tool == 'cat'
      if value
        @auser.cats << Cat.find(tool_id)
      else
        @auser.cats.delete(Cat.find(tool_id))
      end
    elsif tool == 'smartphone'
      if value
        @auser.phones << Phone.find(tool_id)
      else
        @auser.phones.delete(Phone.find(tool_id))
      end
    else
      raise 'Unknown skill'
    end
  end

  def update_tool_others
    unless (@user == @auser) || @user.has_supporter_privileges?
      raise 'Operation not permited'
    end

    tool = params[:tool]
    other = params[:other]
    extra = params[:extra]

    if tool == 'cat'
      other_cat = Cat.find_by(name: 'Others')
      @auser.cats_users.where(cat_id: other_cat.id).each(&:destroy)
      if other
        cu = CatsUser.new(user_id: @auser.id, cat_id: other_cat.id, extra: extra)
        cu.save!
      end
    elsif tool == 'phone'
      other_phone = Phone.find_by(name: 'Others')
      @auser.phones_users.where(phone_id: other_phone.id).each(&:destroy)
      if other
        pu = PhonesUser.new(user_id: @auser.id, phone_id: other_phone.id, extra: extra)
        pu.save!
      end
    else
      raise 'Unknown skill'
    end

    render layout: false
  end

  def update_translation_language_results
    source_lang_id = params[:source_lang_id].to_i
    target_lang_id = params[:target_lang_id].to_i

    if params[:include_unqualified]
      conds = "(users.userstatus NOT IN (#{[USER_STATUS_CLOSED, USER_STATUS_PRIVATE_TRANSLATOR].join(',')}))
        AND EXISTS(SELECT * FROM translator_languages WHERE ((translator_languages.translator_id = users.id)
          AND (translator_languages.language_id = #{source_lang_id})
          AND (translator_languages.type = 'TranslatorLanguageFrom')))"

      if target_lang_id != 0
        conds += "AND EXISTS(SELECT * FROM translator_languages WHERE ((translator_languages.translator_id = users.id)
            AND (translator_languages.language_id = #{target_lang_id})
            AND (translator_languages.type = 'TranslatorLanguageTo')))"
      end

      @translators = Translator.where(conds)
      translators_ids = @translators.pluck(:id)
      @languages =
          Language.joins(:translator_languages).
              select('DISTINCT languages.*').
              where("(translator_languages.type = 'TranslatorLanguageTo') AND (translator_languages.translator_id in (?))", translators_ids)
    else
      conds = "(users.userstatus = #{USER_STATUS_QUALIFIED})
        AND EXISTS(SELECT * FROM translator_languages WHERE ((translator_languages.translator_id = users.id)
          AND (translator_languages.status = #{TRANSLATOR_LANGUAGE_APPROVED})
          AND (translator_languages.language_id = #{source_lang_id})
          AND (translator_languages.type = 'TranslatorLanguageFrom')))"

      if target_lang_id != 0
        conds += " AND EXISTS(SELECT * FROM translator_languages WHERE ((translator_languages.translator_id = users.id)
          AND (translator_languages.status = #{TRANSLATOR_LANGUAGE_APPROVED})
          AND (translator_languages.language_id = #{target_lang_id})
          AND (translator_languages.type = 'TranslatorLanguageTo')))"
      end
      @translators = Translator.where(conds)
      translators_ids = @translators.pluck(:id)
      @languages =
          Language.joins(:translator_languages).
              select('DISTINCT languages.*').
              where("(translator_languages.type = 'TranslatorLanguageTo') AND (translator_languages.status = #{TRANSLATOR_LANGUAGE_APPROVED}) AND (translator_languages.translator_id in (?))", translators_ids)
    end

    unless params[:category_id].blank?
      @translators = @translators.find_all { |t| t.categories.map { |c| c.id.to_s }.include?(params[:category_id]) }
    end
  end

  def supporters
    @header = 'All supporters in the system'
    @ausers = Supporter.all
    render_index
  end

  def my_profile
    @header = _('My Account Overview')
    @auser = @user
    active_items, todos = @user.todos
    @todos = todos if active_items > 0

    if @user[:type] == 'Client'
      @financials_title = _('Deposits and payments')
      @financials_description = _("View your account's history, deposit more money to your account and get printable tax invoices.")
    else
      @financials_title = 'Payments and withdrawals'
      @financials_description = "View your account's history, see payments that you've received, make withdrawals and get tax invoices"
    end
  end

  def request_practice_project
    @projects_exist = !@user.get_ta_chats.empty?
    @header = if @projects_exist
                'Complete your existing practice project'
              else
                'Request a practice project'
              end
    @from_languages = {}
    @user.from_languages.each { |l| @from_languages[l.name] = l.id }

    # if there's only one source language, delete it from the destination languages list
    @to_languages = []
    @user.translator_language_tos.each do |tl|
      lang = tl.language
      unless (@from_languages.length == 1) && (@from_languages.values[0] == lang.id)
        @to_languages << lang
      end
    end

    if @from_languages.empty? || @to_languages.empty?
      flash[:notice] = 'Please wait for the staff to validate your translation languages before you can "do basic training"'
      redirect_to action: :my_profile
    end
  end

  def setup_practice_project
    # look for a practice project for this translator

    unless @user.get_ta_chats.empty?
      flash[:notice] = 'A practice project has already been created for you'
      redirect_to action: :request_practice_project
      return
    end

    source_language_id = params[:source_language_id].to_i

    begin
      if params[:target_language].is_a? Array
        to_lang_list = make_dict(params[:target_language].first)
      elsif params[:target_language].is_a? ActionController::Parameters
        to_lang_list = make_dict(params[:target_language].to_hash)
      else
        raise 'Undefined type'
      end
    rescue => e
      logger.debug "Error catched: #{e.inspect}"
      to_lang_list = []
    end

    to_lang_list.delete(source_language_id)

    ok = false
    if (source_language_id > 0) && !to_lang_list.empty?
      ok = true
      # verify the source language
      begin
        source_language = Language.find(source_language_id)
        dest_languages = Language.find(to_lang_list)
      rescue
        ok = false
        err_msg = _('Some of the languages you selected cannot be located.')
      end
    else
      err_msg = _('You must select at least one destination language for the practice project.')
    end

    # search for a practice project with this source language
    if ok
      practice_user = User.where(email: PRACTICE_USER_EMAIL).first
      unless practice_user
        ok = false
        err_msg = 'Practice users were not yet set up.'
      end
    end

    if ok
      practice_project = practice_user.projects.joins(:revisions).where(["revisions.language_id=#{source_language_id}"]).first
      unless practice_project
        source_language_id = Language.find_by(name: 'English').id
        practice_project = practice_user.projects.joins(:revisions).where(["revisions.language_id=#{source_language_id}"]).first
      end

      unless practice_project
        ok = false
        err_msg = "Can't find practice project for this language: #{source_language.name}"
      end

    end

    unless ok
      flash[:notice] = err_msg
      redirect_to action: :request_practice_project
      return
    end

    practice_revision = practice_project.revisions.where(["revisions.language_id=#{source_language_id}"]).first
    unless practice_revision
      practice_revision = practice_project.revisions.where(["revisions.language_id=#{Language.find_by(name: 'English').id}"]).first
    end

    practice_client = User.where(email: DEMO_CLIENT_EMAIL).first
    unless practice_client
      practice_client = Client.create!(fname: DEMO_CLIENT_FNAME,
                                       lname: DEMO_CLIENT_LNAME,
                                       nickname: DEMO_CLIENT_NICKNAME,
                                       email: DEMO_CLIENT_EMAIL,
                                       password: DEMO_CLIENT_PASSWORD,
                                       userstatus: USER_STATUS_REGISTERED)
    end

    # create a project and assign to the translator
    sn = SerialNumber.create!
    proj_name = "Practice project for #{@user.full_name} (#{sn.id})"
    project = Project.new(name: proj_name,
                          creation_time: Time.now)
    project.client = practice_client
    project.save!

    source_language_id = 1
    day_to_complete = 14
    rev_name = 'Initial'
    revision = Revision.new(name: rev_name.gsub(/\/\\/, '_'),
                            description: "Practice project, made exclusively for #{@user.full_name}",
                            language_id: source_language_id,
                            released: 1,
                            max_bid: 0,
                            max_bid_currency: 1,
                            bidding_duration: 1,
                            project_completion_duration: day_to_complete,
                            creation_time: Time.now)
    revision.project = project
    revision.save!

    # copy all support files
    support_file_ids = {}
    practice_revision.support_files.each do |practice_support_file|
      support_file = SupportFile.new(chgtime: Time.now,
                                     content_type: practice_support_file.content_type,
                                     filename: practice_support_file.filename,
                                     size: practice_support_file.size)
      support_file.project = project

      support_file.save!

      # fix the filename given the correct file ID
      support_file.filename = "id#{support_file.id}.gz"
      support_file.save!

      FileUtils.mkdir_p(File.dirname(support_file.full_filename))
      FileUtils.copy(practice_support_file.full_filename, support_file.full_filename)

      RevisionSupportFile.create(support_file_id: support_file.id,
                                 revision_id: revision.id)

      support_file_ids[practice_support_file.id] = support_file.id

    end

    # copy the version from the original revision and change the revision ID in the XML
    practice_revision.versions.each do |practice_version|

      version = ::Version.new(chgtime: Time.now,
                              content_type: practice_version.content_type,
                              filename: practice_version.filename,
                              size: practice_version.size)
      version.revision = revision
      version.user = practice_client
      version.save!

      stream = practice_version.get_contents
      listener = XmlRevisionChanger.new(proj_name, rev_name, revision.id, support_file_ids)
      parser = REXML::Parsers::StreamParser.new(stream, listener)
      parser.parse

      FileUtils.mkdir_p(File.dirname(version.full_filename))
      Zlib::GzipWriter.open(version.full_filename) do |gz|
        gz.write listener.result
      end

      version.size = File.size(version.full_filename)
      version.save!

      version.update_statistics(@user)
    end

    # create a chat, assign to the translator
    chat = Chat.new(translator_has_access: 0)
    chat.revision = revision
    chat.translator = @user
    chat.save!

    # Create the starting chat message
    msg = <<-WELCOME_MESSAGE
      Hi #{@user.nickname},

      Welcome to the Practice Project section. The idea is to get you familiar with Translation Assistant so that when you start working on live projects you are comfortable with the software.
      Please read the following information before you get you started:
      http://docs.icanlocalize.com/information-for-translators/practice-projects/
      http://docs.icanlocalize.com/information-for-translators/getting-started-with-translation-assistant/
      http://docs.icanlocalize.com/information-for-translators/getting-started-with-translation-assistant/how-to-select-different-pages-to-translate/
      http://docs.icanlocalize.com/information-for-translators/getting-started-with-translation-assistant/how-to-use-formating-markers-in-translation-assistant/

      If at any point you need help or should you have any questions, do get in touch with us.
      Good luck!
    WELCOME_MESSAGE
    create_message_in_chat(chat, practice_client, [@user], msg)

    # create revision languages and bids with zero sum. The bids will be in an accepted state
    dest_languages.each do |language|
      revision_language = RevisionLanguage.new
      revision_language.revision = revision
      revision_language.language = language
      revision_language.save!

      revision_language.managed_work = ManagedWork.default(from_language_id: revision.language.id,
                                                           to_language_id: language.id)

      bid = Bid.new(status: BID_ACCEPTED,
                    amount: 0,
                    currency_id: 1,
                    accept_time: Time.now,
                    expiration_time: Time.now + day_to_complete * DAY_IN_SECONDS)
      bid.chat_id = chat.id
      bid.revision_language = revision_language
      bid.save!

      bid_account = BidAccount.new(currency_id: 1)
      bid_account.bid = bid
      bid_account.save!
    end

    # find all the user's sessions and update the counter
    @user.user_sessions.each { |session| session.update_attributes(counter: session.counter + 1) }

    @header = _('Practice project created')

    # send the getting started email
    if (@user.work_revisions.length == 1) && @user.can_receive_emails?
      ReminderMailer.ta_getting_started_instructions(@user).deliver_now
    end

  end

  # GET /users/1
  # GET /users/1.xml
  def show
    @deleted = (@auser.userstatus == USER_STATUS_CLOSED)
    @client = @user.is_client? ? @user : nil

    if @user.has_supporter_privileges?
      @user_downloads = @auser.user_downloads
      @created_issues = @auser.created_issues.order('status ASC')
      @targeted_issues = @auser.targeted_issues.order('status ASC')

      @client = User.find(params[:in_behalf_of]) if params[:in_behalf_of]
    end

    @header = @user == @auser ? 'Your profile' : (@user[:type] == 'Client') && @user.private_translators.where(translator_id: @auser.id).first ? '%s %s (%s)' % [@auser.fname, @auser.lname, @auser.full_name] : @auser.full_name

    if @auser[:type] == 'Translator'
      @languages = @auser.all_languages.where(name: 'English')
    end

    if ((@user == @auser) || @user.has_supporter_privileges?) && (@auser[:type] == 'Client')
      @websites_to_update = @auser.websites.where(['websites.accesskey_ok != ?', ACCESSKEY_VALIDATED])
    end

    @back = request.referer

    respond_to do |format|
      format.html # show.rhtml
      format.xml { render xml: @auser.to_xml }
    end
  end

  def supporter_password
    if @user.has_supporter_privileges? && @auser.is_a?(Translator)
      @supporter_password = @auser.create_supporter_password
    end
  end

  def webta_access
    if @user.has_supporter_privileges? && @auser.is_a?(Translator)
      @auser.update_attribute(:beta_user, !@auser.beta_user)
    end
  end

  # GET /users/new
  def new
    @auser = NormalUser.new
    @auser.source = !params[:source].blank? ? params[:source] : request.referer
    @auser.next_operation = params[:next_operation] if params[:next_operation]

    set_source

    if @utype == 'Client'
      @header = ''
      render(action: :new_client, layout: @translation_analytics ? 'empty' : true)
    elsif @utype == 'Partner'
      @header = _('Become a partner')
    else
      @header = _('Sign up for a translator account')
    end
  end

  # GET /users/1;edit
  def edit
    @header = "Edit #{owner_name} profile"
  end

  # POST /users
  # POST /users.xml
  def create
    ok = true
    @translation_analytics = !params[:translation_analytics].blank?

    if %w(Client Partner Translator).include? @utype
      @auser = @utype.constantize.new(params[:auser])
      @auser.last_login = Time.now
      @auser.notifications = NEWSLETTER_NOTIFICATION
      @auser.notifications |= DAILY_RELEVANT_PROJECTS_NOTIFICATION if @utype == 'Translator'
    else
      @auser = NormalUser.new(params[:auser])
      @auser.errors.add(:base, _('User type not selected'))
      @utype_error = true
      ok = false
    end

    @auser.signup_date = Time.now
    @auser.display_options = DISPLAY_AFFILIATE
    @auser.loc_code = session[:loc_code]
    set_source

    unless session[AFFILIATE_CODE_COOKIE].blank?
      affiliate = User.find_by(id: session[AFFILIATE_CODE_COOKIE].to_i)
      @auser.affiliate = affiliate
    end

    @auser.userstatus = if Rails.env == 'sandbox'
                          if @auser[:type] == 'Translator'
                            AUTOMATIC_TRANSLATOR_APPROVAL ? USER_STATUS_QUALIFIED : USER_STATUS_NEW
                          else
                            USER_STATUS_REGISTERED
                          end
                        else
                          USER_STATUS_NEW
                        end

    email_already_exists = false
    if User.find_by(email: @auser.email)
      @auser.errors.add(:base, _('E-Mail already in use')) unless @translation_analytics
      email_already_exists = true
      ok = false
    end

    unless @translation_analytics
      if User.find_by(nickname: @auser.nickname)
        @auser.errors.add(:base, _('Nickname already in use'))
        ok = false
      end
      if !params[:accept_agreement] && (@utype != 'Partner')
        @user_agreement_not_accepted = true
        @auser.errors.add(:base, _('You must accept the user agreement'))
        ok = false
      end
    end

    if @translation_analytics
      unless @user.blank?
        @auser.generate_nickname
        @auser.generate_password
      end
    elsif ok
      captcha_image = CaptchaImage.find_by(id: params[:captcha_id].to_i)

      if ok && (Rails.env != 'sandbox') && !(captcha_image && params[:code].casecmp(captcha_image.code.downcase).zero?)
        logger.info ' -------- bad captcha code'
        ok = false
        @captcha_error = true
        @auser.errors.add(:base, _("Verification code doesn't match"))
      end

      captcha_image.destroy if captcha_image
    end

    if ok
      ok = @auser.save
      logger.info " ----------- saved: #{ok}"
    end

    # Decide where to go next
    page_from = nil
    extra_params = nil
    if @translation_analytics
      @wid = params[:wid]
      @accesskey = params[:accesskey]
      raise 'No wid' unless @wid
      raise 'No Accesskey' unless @accesskey

      page_from = 'translation_analytics'
      extra_params = { wid: @wid, accesskey: @accesskey }
      extra_params[:email] = @auser.email if email_already_exists
    end

    if @auser.can_receive_emails?
      ReminderMailer.user_should_complete_registration(@auser, nil, page_from, extra_params).deliver_now if ok
    end

    respond_to do |format|
      if ok
        @header = _('Registration email sent!')
        format.html { render layout: @translation_analytics ? 'empty' : true }
        format.xml
      else
        format.html do
          if @utype == 'Client'
            @header = ''
            if @translation_analytics
              flash[:notice] = ''
              @auser.errors.full_messages.each { |x| flash[:notice] += "<li>#{x}</li>" }
              redirect_to({ controller: 'login', action: 'login_or_create_account', translation_analytics: @translation_analytics }.merge(extra_params))
            else
              render(action: :new_client)
            end
          else
            @header = _('Sign up for an account')
            render action: 'new'
            # @utypes = [[_('Website owner'), 'Client'], [_('Translator'), 'Translator']]
          end
        end
        format.xml { render xml: @auser.errors.to_xml }
      end
    end
  end

  def resend_activation_email
    begin
      @user = User.find(params[:id].to_i)
    rescue
    end

    @translation_analytics = !params[:translation_analytics].blank?

    message = 'Something did not go right here. We suggest that you start over.'

    if @user && (@user.password_reset_signature(params[:signature]) == PASSWORD_HASH_SECRET)

      page_from = nil
      extra_params = nil
      if @translation_analytics
        @wid = params[:wid]
        @accesskey = params[:accesskey]
        raise 'No wid' unless @wid
        raise 'No Accesskey' unless @accesskey
        page_from = 'translation_analytics'
        extra_params = { wid: @wid, accesskey: @accesskey }
      end

      if @user.can_receive_emails?
        ReminderMailer.user_should_complete_registration(@user, nil, page_from, extra_params).deliver_now
      end
      message = 'We just sent you another activation email!'
    end
    @message = message
  end

  def validate
    begin
      @auser = User.find(params[:id])
    rescue
      set_err('Cannot find this user')
      return false
    end

    unless @auser.password_reset_signature(params[:signature]) == PASSWORD_HASH_SECRET
      set_err('Bad validation code, please make sure the link you clicked on is correct and complete.')
      return false
    end

    @header = _('Your email address has been validated!')
    @next_action = 0
    next_url = nil
    if @auser[:type] == 'Client'

      project_type = find_user_source(@auser.source)

      next_url = if (project_type == 'iphone') || (project_type == 'android') || (project_type == 'software')
                   { controller: :text_resources, action: :new }
                 elsif project_type == 'drupal'
                   { controller: :client, action: :getting_started4, cms_kind: WEBSITE_DRUPAL }
                 elsif project_type == 'wordpress'
                   { controller: :client, action: :getting_started4, cms_kind: WEBSITE_WORDPRESS }
                 elsif project_type == 'hm'
                   { controller: :client, action: :translate_with_ta, what: 'Help and Manual project' }
                 elsif (project_type == 'html') || (project_type == 'hm')
                   { controller: :client, action: :translate_with_ta }
                 elsif project_type == 'affiliate'
                   { controller: :my }
                 else
                   { controller: :client, action: :getting_started }
                 end

      if @auser.support_tickets.empty?
        send_welcome(@auser) unless params[:translation_analytics]
      end
    else
      ReminderMailer.welcome_translator(@auser).deliver_now
      next_url = { action: :my_profile }
    end

    if @auser.userstatus != USER_STATUS_REGISTERED
      @auser.update_attributes(userstatus: USER_STATUS_REGISTERED, scanned_for_languages: 0)
    end

    create_session_for_user(@auser)

    flash[:notice] = _("Thank you for validating your email. Let's get started!")

    if params[:translation_analytics]
      raise 'Unknwon wid' unless params[:wid]
      raise 'Unknown accesskey' unless params[:accesskey]
      website = Website.where(['id = ? AND accesskey = ?', params[:wid], params[:accesskey]]).first
      if website
        anon_client = website.client
        website.client = @auser
        website.save!
        anon_client.destroy if anon_client
      end
      flash[:notice] = _('Your account is now assigned to this website.')
      next_url = { controller: 'translation_analytics', wid: params[:wid], accesskey: params[:accesskey] }
      render action: 'translation_analytics_welcome', layout: false
      return
    end

    redirect_to(next_url)

  end

  def edit_personal_details
    req = params[:req]
    reload = false

    if params[:auser] && params[:auser][:birthday]
      params[:auser][:birthday] = if params[:auser][:birthday].first.blank?
                                    nil
                                  else
                                    params[:auser][:birthday].first.to_date
                                  end
    end

    @show_edit = nil
    if (req == 'save') || req.nil?
      websites_to_check = @auser[:type] == 'Client' ? @auser.websites : []

      password_changed = @auser.get_password != params[:auser][:password]

      @auser.update_attribute :bounced, false if password_changed

      # remember the values of the accesskeys
      previous_accesskeys = {}
      websites_to_check.each { |w| previous_accesskeys[w] = w.accesskey }

      # Update all user attributes received in the params hash
      @auser.assign_attributes(params[:auser])

      reload = true if @auser.userstatus_changed?
      @show_edit = @auser.save ? nil : true

      websites_to_check.each do |w|
        w.reload
        if previous_accesskeys[w] != w.accesskey
          w.update_attributes!(accesskey_ok: ACCESSKEY_NOT_VALIDATED)
        end
      end

    elsif req == 'show'
      @show_edit = true
    end

    if params['request_action'] == 'update_vat'
      vat = Vat.new(@auser, params[:auser][:country_id], params[:auser][:vat_number])
      render json: {
          tax_rate: vat.get_user_tax_rate,
          validation_success: vat.vat_number_has_been_validated,
          tax_enabled: vat.has_to_pay_tax
      }
      return
    end

    @reload = reload
  end

  def validate_user_vat
    if params[:auser][:country_id].present? || params[:auser][:vat_number].present?
      @user.update_attributes(params[:auser]) unless params[:auser][:country_id].to_i == 0
    end
    @vat = Vat.new(@auser, params[:auser][:country_id], params[:auser][:vat_number])
  end

  def translator_languages
    @header = 'Edit translation languages'
    setup_from_languages
    setup_to_languages
  end

  def add_language_document
    warnings = []
    reload = false
    need_html_replace = false
    flash_div = nil
    need_save = false

    begin
      translator_language = TranslatorLanguage.find(params[:translator_language_id].to_i)
    rescue
      translator_language = nil
    end

    unless translator_language && (translator_language.translator_id == @user.id)
      warnings << 'There was a problem with your form, please try again.'
      reload = true
      return
    end

    if !params[:tl_description].blank? && (params[:tl_description] != translator_language.description)
      translator_language.description = params[:tl_description]
      need_save = true
    elsif params[:tl_description].blank? && translator_language.description.blank?
      warnings << 'Please describe your background in this language.'
    end

    if !params[:uploaded_data].blank? && !params[:description].blank?
      translator_language_document = TranslatorLanguageDocument.new(description: params[:description],
                                                                    uploaded_data: params[:uploaded_data])

      translator_language_document.translator_language = translator_language
      translator_language_document.translator = @user
      translator_language_document.save!

      begin
        translator_language_document.save!
        need_html_replace = true
        flash_div = "attachments_for_language#{translator_language.id}"
      rescue ActiveRecord::RecordInvalid
        warnings << 'There was a problem with this attachment upload.'
      end
    elsif !params[:uploaded_data].blank? && params[:description].blank?
      warnings << 'You must enter a document title.'
    elsif params[:uploaded_data].blank? && !params[:description].blank?
      warnings << 'You must select the document file to be uploaded from your computer.'
    elsif translator_language.translator_language_documents.empty?
      warnings << 'You must add a document which proves your language skills.'
    end

    if (translator_language.status != TRANSLATOR_LANGUAGE_APPROVED) &&
        !translator_language.description.blank? &&
        !translator_language.translator_language_documents.empty?
      translator_language.status = TRANSLATOR_LANGUAGE_REQUEST_REVIEW
      need_save = true
      need_html_replace = true
      warnings << 'A staff member will review the documents you submitted shortly in order to approve your translation language.'
      Admin.all.each do |admin|
        if admin.send_admin_notifications
          ReminderMailer.translation_language_pending(admin, @user, translator_language).deliver_now
        end
      end

    end

    translator_language.save! if need_save

    if need_html_replace
      if translator_language[:type] == 'TranslatorLanguageFrom'
        partial = 'from_languages'
        setup_from_languages
      else
        partial = 'to_languages'
        setup_to_languages
      end
    end
    @warning = warnings.join("\n")
    @need_html_replace = need_html_replace
    @flash_div = flash_div
    @partial = partial
    @reload = reload
  end

  def del_language_document
    begin
      document = TranslatorLanguageDocument.find(params[:doc_id])
    rescue
      document = nil
    end

    if document && (document.translator == @user)
      translator_language = document.translator_language
      document.translator_language.translator_language_documents.delete(document)
      document.destroy

      if translator_language.translator_language_documents.empty?
        translator_language.update_attributes(status: TRANSLATOR_LANGUAGE_NEW)
      end
    end

    setup_from_languages
    setup_to_languages

  end

  def add_from_languages
    @show_from_language_selection = nil # set the default value - don't show the list

    lang_id = params[:from_lang_id].to_i
    if lang_id == 0
      @warning = 'No language selected. Please select a language from the list and try again.'
    end

    lang = Language.where(["(languages.id=#{lang_id}) AND NOT EXISTS(SELECT * FROM translator_languages WHERE (translator_languages.translator_id=#{@user.id}) AND (translator_languages.language_id=#{lang_id}) AND (translator_languages.type='TranslatorLanguageFrom'))"]).first
    @reload = true unless lang

    if !@warning && !@reload
      translator_language = TranslatorLanguageFrom.new(language_id: lang_id)
      if Rails.env == 'sandbox'
        translator_language.status = AUTOMATIC_TRANSLATOR_APPROVAL ? TRANSLATOR_LANGUAGE_APPROVED : TRANSLATOR_LANGUAGE_NEW
        @auser.update_attributes(scanned_for_languages: 0)
      end
      translator_language.translator = @auser
      translator_language.save!
      @dest_id = "translator_language#{translator_language.id}"
      setup_from_languages
    end
  end

  def add_to_languages
    @show_to_language_selection = nil # set the default value - don't show the list

    lang_id = params[:to_lang_id].to_i
    if lang_id == 0
      @warning = 'No language selected. Please select a language from the list and try again.'
    end

    lang = Language.where(["(languages.id=#{lang_id}) AND NOT EXISTS(SELECT * FROM translator_languages WHERE (translator_languages.translator_id=#{@user.id}) AND (translator_languages.language_id=#{lang_id}) AND (translator_languages.type='TranslatorLanguageTo'))"]).first
    @reload = true unless lang

    if !@warning && !@reload
      translator_language = TranslatorLanguageTo.new(language_id: lang_id)
      if Rails.env == 'sandbox'
        translator_language.status = AUTOMATIC_TRANSLATOR_APPROVAL ? TRANSLATOR_LANGUAGE_APPROVED : TRANSLATOR_LANGUAGE_NEW
        @auser.update_attributes(scanned_for_languages: 0)
      end
      translator_language.translator = @auser
      translator_language.save!
      @dest_id = "translator_language#{translator_language.id}"
      setup_to_languages
    end
  end

  def del_language
    tl_id = params[:tl_id].to_i
    begin
      translator_language = @auser.translator_languages.find(tl_id)
    rescue
      translator_language = nil
      @warning = 'No language selected. Please select a language from the list and try again.'
    end

    if translator_language
      if translator_language
        @auser.translator_languages.delete(translator_language)
        translator_language.destroy
        if translator_language[:type] == 'TranslatorLanguageFrom'
          partial = 'from_languages'
          setup_from_languages
        else
          partial = 'to_languages'
          setup_to_languages
        end
      else
        @reload = true
      end
    end
    @partial = partial
  end

  def edit_language
    tl_id = params[:tl_id].to_i
    begin
      translator_language = @auser.translator_languages.find(tl_id)
    rescue
      set_err('no language')
      return
    end

    req = params[:req]
    if req == 'show'
      @editing_language_description = tl_id
    elsif req.nil?
      translator_language.update_attributes(description: params[:tl_description])
    end

    if translator_language[:type] == 'TranslatorLanguageFrom'
      partial = 'from_languages'
      setup_from_languages
    else
      partial = 'to_languages'
      setup_to_languages
    end
    @partial = partial
  end

  def edit_categories
    @show_categories_selection = nil # set the default value - don't show the list
    req = params[:req]
    if req == 'show'
      @show_categories_selection = true

      # setup a list of languages
      user_category_ids = @auser.categories.collect(&:id)
      @categories = Category.all.collect { |cat| [cat.id, cat.name, user_category_ids.include?(cat.id)] }

    elsif req == 'save'
      begin
        cat_list = make_dict(params[:category])
      rescue
        cat_list = []
        logger.info('   ---> Cannot find category list!')
      end

      # OK - now, create the new table entries
      # drop any current languag that's not marked
      to_remove = []
      for trans_cat in @auser.translator_categories
        to_remove << trans_cat unless cat_list.include?(trans_cat.category_id)
      end

      for trans_cat in to_remove
        @auser.translator_categories.delete(trans_cat)
        trans_cat.destroy
      end

      # add any language that doesn't yet appear
      cat_list.each do |id|
        cat = TranslatorCategory.where(['translator_id = ? AND category_id = ?', @auser.id, id]).first
        unless cat
          cat = TranslatorCategory.new(category_id: id)
          @auser.translator_categories << cat
        end
      end
      @auser.save!
      @auser.categories(true)
    end
  end

  def edit_resume
    @warning = nil
    @show_resume_edit = nil # set the default value - don't show the list
    req = params[:req]
    if req == 'show'
      @show_resume_edit = true
      @resume = @auser.resume || Resume.new
    elsif (req == 'save') || req.nil?
      if @auser.resume
        @auser.resume.assign_attributes(params[:resume])
      else
        @auser.resume = Resume.create(title: 'Resume')
        @auser.save!
        @auser.resume.assign_attributes(params[:resume])
      end
      if @auser.resume.valid?
        @auser.resume.save
      else
        @warning = list_errors(@auser.resume.errors.full_messages, false)
      end
    end
  end

  def edit_translation_availability
    @edit_translation_availability = nil
    req = params[:req]
    if req == 'show'
      @edit_translation_availability = true
    elsif (req == 'save') || req.nil?
      @auser.update_attributes(params[:auser].merge(scanned_for_languages: 0))
    end
  end

  # PUT /users/1
  # PUT /users/1.xml
  def update
    respond_to do |format|
      if @auser.update_attributes(params[:auser])
        flash[:notice] = _('User was successfully updated.')
        format.html { redirect_to user_url(@auser) }
        format.xml { head :ok }
      else
        logger.info('-------- did not update user')
        logger.info(@auser.errors.full_messages)
        format.html { render action: 'edit' }
        format.xml { render xml: @auser.errors.to_xml }
      end
    end
  end

  def update_public
    @auser.update_attributes!(is_public: params[:is_public].to_i == 1 ? 1 : 0)
  end

  def update_bio
    bio = params[:bio].strip
    @message = 'Your bio-note has been updated'
    if bio.length > 500
      @message = 'This bio note is too long. Use only 500 characters.'
    else
      if !@auser.bionote
        bionote = Bionote.new(body: bio)
        bionote.owner = @auser
        bionote.chgtime = Time.now
        bionote.save
      else
        @auser.bionote.update_attributes!(body: bio, chgtime: Time.now)
      end
    end
  end

  def update_rate
    rate = params[:rate].to_f
    capacity = params[:capacity].to_i

    warnings = []

    if rate < MINIMUM_BID_AMOUNT
      warnings << 'You cannot enter a rate below %.2f USD / word.' % MINIMUM_BID_AMOUNT
    end

    if capacity == 0
      warnings << "Please enter your work capacity. It's not rocket science, you can estimate."
    end

    if warnings.empty?
      @warning = warnings.join("\n")
      @auser.update_attributes!(rate: rate, capacity: capacity)
    end
  end

  def update_autoassignment
    return if params[:autoassignments].blank?

    @auser.language_pair_autoassignments.destroy_all

    autoassign_languages = params[:autoassignments].values.select { |v| v[:autoassign] == '1' }.map do |autoassign_params|
      @auser.language_pair_autoassignments.create autoassign_params.slice(:from_language_id, :to_language_id, :min_price_per_word)
    end

    @errors = autoassign_languages.select { |a| a.errors.any? }
    @errors = Hash[@errors.map do |l|
      error_description = "#{l.from_language.name} - #{l.to_language.name}: #{l.errors.messages.values.flatten.join(', ')}"
      ["#{l.from_language.id}_#{l.to_language.id}", error_description]
    end]
  end

  def edit_image
    req = params[:req]

    if req.nil?
      warnings = []
      image = nil
      if !params[:uploaded_data].blank?
        image = Image.new(uploaded_data: params[:uploaded_data])
        image = nil unless image.save
      else
        warnings << _('You must select the file to upload.')
      end

      # if the original upload is OK, check if it is an image file
      if image
        extention_idx = image.filename.rindex('.')
        extention = image.filename[(extention_idx + 1)..-1].downcase

        logger.info "------ extention: #{extention}, image.width=#{image.width}, image.height=#{image.height}"
        if %w(jpg jpeg png gif).include?(extention) && (image.width > 0) && (image.height > 0)
          if (image.width > 100) || (image.height > 100)
            rimg = Magick::Image.read(image.full_filename)[0]
            rimg.resize_to_fit!(100, 100)

            image.width = rimg.columns
            image.height = rimg.rows
            image.save!

            # ensure that the path exists and save the new photo
            FileUtils.mkdir_p(File.dirname(image.full_filename))
            rimg.write(image.full_filename)
          end
        else
          image.destroy
          image = nil
        end
      end

      if image
        @user.image.destroy if @user.image

        image.owner = @user
        image.save
        warnings << 'Success'
      else
        warnings << 'Does not look like an image file'
      end
      @warning = warnings.join("\n")
      @image = image
    else
      @editing_photo = true if req == 'show'
    end
    @req = req
  end

  # DELETE /users/1
  # DELETE /users/1.xml
  # def destroy
  # @auser.destroy

  # respond_to do |format|
  #   format.html { redirect_to users_url }
  #   format.xml  { head :ok }
  # end
  # end

  def verification
    @header = 'Identify verification'
    @accounts_to_verify = @user.external_accounts unless @user.verified?
  end

  def do_verification_deposit
    create_deposit_from_external_account(@user, 0.1, DEFAULT_CURRENCY_ID)
  end

  def request_external_account_validation
    acc_id = params[:acc_id].to_i
    ok = false
    if acc_id > 0
      begin
        account = ExternalAccount.find(acc_id)
      rescue
        account = nil
      end
      if account && (account.normal_user == @user) && (@user.userstatus != USER_STATUS_CLOSED)
        ReminderMailer.external_account_validation(account, @user).deliver_now
        ok = true
      end
    end

    @acc_id = acc_id
    @ok = ok
  end

  def validate_external_account
    acc_id = params[:acc_id].to_i
    ok = false
    if acc_id > 0
      begin
        account = ExternalAccount.find(acc_id)
      rescue
        account = nil
      end
      if account && (account.normal_user == @user) && (account.signature == params[:signature])
        iv = IdentityVerification.new(chgtime: Time.now,
                                      status: VERIFICATION_OK)
        iv.normal_user = @user
        iv.verified_item = account
        iv.save!
        ok = true
      end
    end
    msg = if ok
            _('Thank you! Your PayPal email has been verified.')
          else
            "There was a problem with the link you clicked, try to copy and paste the entire link to the browser's address."
          end

    flash[:notice] = msg
    redirect_to action: :verification, id: @user.id
  end

  def add_verification_document
    warnings = []
    ok = false
    if !params[:uploaded_data].blank? && !params[:description].blank?
      user_identity_document = UserIdentityDocument.new(description: params[:description],
                                                        uploaded_data: params[:uploaded_data])

      user_identity_document.normal_user = @user
      user_identity_document.save!

      begin
        user_identity_document.save!
        ok = true
      rescue ActiveRecord::RecordInvalid
        warnings << 'There was a problem with this attachment upload.'
      end

      if ok
        identity_verification = IdentityVerification.new(status: VERIFICATION_PENDING,
                                                         chgtime: Time.now)
        identity_verification.verified_item = user_identity_document
        identity_verification.normal_user = @user
        identity_verification.save!
        warnings << 'Your document was successfully uploaded. A staff member will review it shortly.'
      else
        warnings << 'We had a problem processing this document. Please try again.'
      end

    elsif !params[:uploaded_data].blank? && params[:description].blank?
      warnings << 'You must enter a document title.'
    elsif params[:uploaded_data].blank? && !params[:description].blank?
      warnings << 'You must select the document file to be uploaded from your computer.'
    else
      warnings << "You must enter the document's title and select the document to upload."
    end
    @warning = warnings.join("\n") unless warnings.empty?
    @ok = ok
  end

  def del_verification_document
    vd_id = params[:vd_id].to_i
    ok = false
    if vd_id > 0
      begin
        verification_document = UserIdentityDocument.find(vd_id)
      rescue
        verification_document = nil
      end
      if verification_document && (verification_document.normal_user == @user)
        verification_document.destroy
        ok = true
      end
    end
    @ok = ok
  end

  def update_password
    new_password = params[:new_password]
    verify_password = params[:verify_password]
    msg = if new_password.blank? || verify_password.blank?
            _('You must enter the new password in both fields')
          elsif new_password != verify_password
            _('The new password must match in both fields')
          else
            msg = if @user.update_attributes(password: new_password)
                    _('Your password has been updated')
                  else
                    _('Your password could not be updated')
                  end
          end
    @msg = msg
  end

  def update_display_settings
    display_options = 0
    if params[:display_web_supports].to_i == 1
      display_options += DISPLAY_WEB_SUPPORTS
    end
    display_options += DISPLAY_AFFILIATE if params[:display_affiliate].to_i == 1
    display_options += DISPLAY_SEARCH if params[:display_search].to_i == 1
    display_options += DISPLAY_GLOSSARY if params[:display_glossary].to_i == 1
    @user.update_attributes(display_options: display_options)
    flash[:notice] = _('Display options updated')
    redirect_to action: :my_profile
  end

  def close_account
    go_home = false
    if @auser.money_accounts.try(:first).try(:balance).to_f > 0.01
      msg = _('You need to withdraw the money from your account before close it')
    elsif params[:verify_password].blank?
      msg = _('Please enter your account password for verification.')
    elsif @auser.get_password == params[:verify_password]
      @auser.update_attributes!(userstatus: USER_STATUS_CLOSED)
      @auser.user_sessions.each(&:destroy)
      if @auser.can_receive_emails?
        ReminderMailer.user_close_account(@auser).deliver_now
      end
      msg = _('Your account has been closed.')
      go_home = true
    else
      msg = _('The password you entered does not match our records.')
    end

    @go_home = go_home
    @msg = msg

    respond_to do |f|
      f.html { render plain: 'ok' }
      f.js
    end
  end

  def reset_password
    begin
      @auser = User.find(params[:id])
    rescue
      set_err('Cannot find this user')
      return
    end

    unless @auser.password_reset_signature(params[:s]) == PASSWORD_HASH_SECRET
      set_err('The link to clicked seems broken. If you cannot click it in your email problem, copy and paste the entire link to a browser.')
      return
    end
    @password = Faker::Code.asin
    @header = _('Your password has been reset')
    @auser.update_attributes(password: @password)
  end

  def managed_works
    # this page should not be visited by admin
    if @user.has_supporter_privileges?
      flash[:notice] = 'Unable to access that page.'
      request.referer ? (redirect_to :back) : (redirect_to '/supporter')
      return
    end
    @header = _('Review work for clients')
  end

  def top
    @header = 'Top clients'
    clients = Client.all
    @clients_deposits = ActiveRecord::Base.connection.exec_query("
        select u.*, sum(mt.amount) as total from users as u
          inner join money_accounts as ma on u.id = ma.owner_id
          inner join money_transactions as mt on ma.id = mt.target_account_id
         where u.type = 'Client'
           and ma.type='UserAccount'
           and mt.target_account_type='MoneyAccount'
         GROUP by u.id
         ORDER by total desc
    ")
  end

  def clients_by_source
    @header = 'Clients by Source'
    date_start = params[:created_date_start] ||= Date.today - 1.month
    date_end = params[:created_date_end] ||= Date.today
    @users = Client.where.not(source: nil).where(signup_date: date_start..date_end)

    unless params[:cvsformat].nil?

      res = [%w(Id Email Nickname SignupDate Source URL)]

      @users.each do |user|
        res << [
          user.id,
          user.email,
          user.nickname,
          user.signup_date.to_time,
          user.source,
          user_path(user)
        ]
      end
      csv_txt = (res.collect { |row| (row.collect { |cell| cell.is_a?(Numeric) ? cell : "\"#{cell}\"" }).join(',') }).join("\n")

      send_data(csv_txt,        filename: 'clients_by_source.csv',
                                type: 'text/plain',
                                disposition: 'downloaded')
    end

  end

  def invite_to_job
    @job_class = params[:job_class]
    @job_id = params[:job_id].to_i
    @div = params[:div]

    # TODO: move to service object
    job = @job_class.classify.constantize.find(@job_id)
    if (job.is_a?(WebMessage) && !@user.can_modify?(job)) || (job.is_a?(ResourceLanguage) && !@user.can_modify?(job.text_resource)) \
      || (job.is_a?(WebsiteTranslationOffer) && !@user.can_modify?(job.website)) || (job.is_a?(RevisionLanguage) && !@user.can_modify?(job.revision))
      set_err("You can't do this.")
      return
    end

    message = params[:message]

    req = params[:req]

    redirect = nil

    if req.blank?
      if message.blank?
        @problem = _('Please enter a message to the translator')
      else

        job = nil

        if @job_class == 'RevisionLanguage'
          begin
            job = RevisionLanguage.find(@job_id)
          rescue
            set_err('cannot find project')
            return
          end
        elsif @job_class == 'ResourceLanguage'
          begin
            job = ResourceLanguage.find(@job_id)
          rescue
            set_err('cannot find project')
            return
          end
        elsif @job_class == 'WebsiteTranslationOffer'
          begin
            job = WebsiteTranslationOffer.find(@job_id)
          rescue
            set_err('cannot find project')
            return
          end
        elsif @job_class == 'ManagedWork'
          begin
            job = ManagedWork.find(@job_id)
          rescue
            set_err('cannot find project')
            return
          end
        else
          @problem = "Don't know how to invite to this project"
        end

        if job && (job.class == ManagedWork)
          logger.info "------ job class is #{job.class}"
          job = job.owner
          logger.info "-- changing to owner - #{job.class}"
        end

        # now, we will send the actual invitation to the translator
        # this means creating a new message in the right place
        if job

          if job.class == RevisionLanguage
            chat = job.revision.chats.where('translator_id=?', @auser.id).first
            if chat
              @problem = _('Translator already invited')
            else
              chat = Chat.new(translator_has_access: 0)
              chat.revision = job.revision
              chat.translator = @auser
              chat.save

              create_message_in_chat(chat, @user, [@auser], message)

              redirect = { controller: :chats, action: :show, id: chat.id, revision_id: chat.revision.id, project_id: chat.revision.project.id }
            end
          elsif job.class == ResourceLanguage
            resource_chat = job.resource_chats.where('translator_id=?', @auser.id).first
            if resource_chat
              @problem = _('Translator already invited')
            else
              resource_chat = ResourceChat.new(status: RESOURCE_CHAT_NOT_APPLIED, word_count: 0)
              resource_chat.resource_language = job
              resource_chat.translator = @auser
              resource_chat.save

              message = Message.new(body: message, chgtime: Time.now)
              message.user = @user
              message.owner = resource_chat
              message.save!

              message_delivery = MessageDelivery.new
              message_delivery.user = @auser
              message_delivery.message = message
              message_delivery.save

              @auser.create_reminder(EVENT_NEW_RESOURCE_TRANSLATION_MESSAGE, resource_chat)
              if @auser.can_receive_emails?
                ReminderMailer.new_message_for_resource_translation(@auser, resource_chat, message).deliver_now
              end

              redirect = { controller: :resource_chats, action: :show, id: resource_chat.id, text_resource_id: job.text_resource.id }
            end
          elsif job.class == WebsiteTranslationOffer
            website_translation_contract = job.website_translation_contracts.where('translator_id=?', @auser.id).first
            if website_translation_contract
              @problem = _('Translator already invited')
            else
              website_translation_contract = WebsiteTranslationContract.new(status: TRANSLATION_CONTRACT_NOT_REQUESTED, currency_id: DEFAULT_CURRENCY_ID)
              website_translation_contract.website_translation_offer = job
              website_translation_contract.translator = @auser
              website_translation_contract.save

              message = Message.new(body: message, chgtime: Time.now)
              message.user = @user
              message.owner = website_translation_contract
              message.save!

              @auser.create_reminder(EVENT_NEW_WEBSITE_TRANSLATION_MESSAGE, website_translation_contract)
              if @auser.can_receive_emails?
                ReminderMailer.new_message_for_cms_translation(@auser, website_translation_contract, message).deliver_now
              end

              redirect = { controller: :website_translation_contracts, action: :show, id: website_translation_contract.id, website_translation_offer_id: job.id, website_id: job.website.id }
            end
          else
            @problem = "Don't know how to invite to this project"
          end
        else
          @problem = "Don't know how to invite to this project"
        end
      end
    end

    @redirect = url_for(redirect)
    @req = req
  end

  def signup
    @back = request.referer
    @return_to = !params[:return_to].blank? ? params[:return_to] : request.referer
    @create_account = true
    @header = _('Your contact details')
  end

  def update_name_and_email
    @create_account = (params[:create_account].to_i == 1)
    @fname = params[:fname]
    @lname = params[:lname]
    @email = params[:email]
    @email1 = params[:email1]
    @password = params[:password]
    @back = params[:back]
    @return_to = params[:return_to]

    @errors = []

    if @create_account
      @errors << 'First name cannot be blank' if @fname.blank?
      @errors << 'Last name cannot be blank' if @lname.blank?
      if @email.blank?
        @errors << 'Email name cannot be blank'
      elsif User.where(['email=?', @email]).first
        @errors << 'Email already exists in our system, use a different one'
      end
    else
      existing_user = Client.where(['email=?', @email1]).first
      if !existing_user || (existing_user.get_password != @password)
        @errors << 'Wrong email or password'
      end
    end

    ok = false

    if @errors.empty?
      if @create_account

        # update the user
        base_nickname = @fname + '.' + @lname[0..0]
        nickname_cnt = User.where(['nickname LIKE ?', base_nickname + '%']).count
        idx = nickname_cnt + 1
        while User.where(['nickname = ?', (base_nickname + idx.to_s)]).first
          idx += 1
        end
        nickname = base_nickname + idx.to_s
        password = Digest::MD5.hexdigest(Time.now.to_s)[0...8].tr('0', '9').tr('1', '3')

        userstatus = USER_STATUS_REGISTERED

        ok = @user.update_attributes(fname: @fname, lname: @lname, email: @email, nickname: nickname,
                                     password: password, userstatus: userstatus, anon: 0)
        if ok && @user.can_receive_emails?
          ReminderMailer.welcome_cms_user(@user, 'Translation Management').deliver_now
        end
      else
        existing_user.transfer_from_other_user(@user)
        @user = existing_user
        @user.reload
        @user_session = create_session_for_user(@user)
        ok = true
      end
    end

    if ok
      if !@return_to.blank?
        flash[:notice] = "Thanks!, now let's continue..."
        redirect_to Rails.application.routes.recognize_path(@return_to)
      else
        redirect_to action: :my_profile
      end
    else
      @header = _('Your contact details')
      render action: :signup
    end
  end

  def edit_affiliate
    req = params[:req]

    warning = nil
    if req.nil?
      logger.info '----------- saving --------------'
      nickname = params[:nickname]
      if nickname.blank?
        @auser.affiliate = nil
        @auser.save!
      else
        affiliate = Client.where(nickname: nickname).first
        affiliate = Translator.where(nickname: nickname).first unless affiliate
        if !affiliate
          warning = 'Not found'
        elsif affiliate == @auser
          warning = 'Cannot be the same user'
        else
          @auser.affiliate = affiliate
          @auser.save!
        end
      end
    elsif req == 'show'
      @edit_affiliate = true
    end
    @warning = warning
  end

  def manage_works
    @translator = Translator.find(params[:id])
  end

  def admins
    @admins = Admin.all
  end

  def toggle_admin_notifications
    @auser = User.find(params[:id])
    @auser.update_attribute :send_admin_notifications, !@auser.send_admin_notifications
    render nothing: true
  end

  def web_messages_list
    @header = @user == @auser ? 'Your profile' : (@user[:type] == 'Client') && @user.private_translators.where(translator_id: @auser.id).first ? '%s %s (%s)' % [@auser.fname, @auser.lname, @auser.full_name] : @auser.full_name

    web_messages = WebMessage.where(owner_id: @auser.id, owner_type: 'User')
    @pager = ::Paginator.new(web_messages.count, PER_PAGE) do |offset, per_page|
      web_messages.order('web_messages.id DESC').limit(per_page).offset(offset)
    end

    @web_messages = @pager.page(params[:page])
    @list_of_pages = []
    for idx in 1..@pager.number_of_pages
      @list_of_pages << idx
    end

  end

  def complete_sandbox
    @user.complete_all_sandbox
    redirect_back(fallback_location: client_index_path)
  end

  def remove_compact_display_session
    render json: { compact_display_is_removed: @user.user_sessions.last.update_attributes(display: nil) }
  end

  def toggle_ta_blocking
    if @user.has_supporter_privileges? && @auser.is_a?(Translator)
      @auser.toggle_ta_blocking
    end
  end

  private

  def render_index
    respond_to do |format|
      format.html { render action: :index }
      format.xml { render xml: @ausers.to_xml }
    end
  end

  def owner_name(cap = false)
    if @user == @auser
      if cap
        'Your'
      else
        'your'
      end
    else
      "#{@auser.full_name}'s"
    end
  end

  def verify_admin
    unless @user.has_admin_privileges?
      set_err('You do not have permission to do that')
      false
    end
  end

  def verify_ownership
    # set up the selected user
    begin
      @auser = User.find(params[:id])
    rescue
      set_err('Cannot find this user')
      return false
    end

    if (@auser.userstatus == USER_STATUS_CLOSED) && !@user.has_supporter_privileges?
      set_err('This user no longer exists in the system')
      return false
    end

    if params[:format] != 'xml'
      @canedit = @user.has_admin_privileges? || (@auser && (@user.id == @auser.id))
    end

    # check access rights
    action = params[:action]
    if (action == 'show') || (action == 'invite_to_job') || (@canedit && (!@orig_user || @orig_user.has_supporter_privileges?))
      return true
    end

    set_err('You do not have permission to do that')
    false

  end

  def setup_from_languages
    @from_languages = []
    @from_languages << ['Select language', 0]
    @from_languages << ['----', 0]
    Language.where(["(languages.major=1) AND NOT EXISTS (SELECT * FROM translator_languages WHERE (translator_languages.translator_id=#{@user.id}) AND (translator_languages.language_id=languages.id) AND (translator_languages.type='TranslatorLanguageFrom'))"]).each { |lang| @from_languages << [lang.name, lang.id] }
    @from_languages << ['----', 0]
    Language.where(["(languages.major=0) AND NOT EXISTS (SELECT * FROM translator_languages WHERE (translator_languages.translator_id=#{@user.id}) AND (translator_languages.language_id=languages.id) AND (translator_languages.type='TranslatorLanguageFrom'))"]).each { |lang| @from_languages << [lang.name, lang.id] }
  end

  def setup_to_languages
    @to_languages = []
    @to_languages << ['Select language', 0]
    @to_languages << ['----', 0]
    Language.where(["(languages.major=1) AND NOT EXISTS (SELECT * FROM translator_languages WHERE (translator_languages.translator_id=#{@user.id}) AND (translator_languages.language_id=languages.id) AND (translator_languages.type='TranslatorLanguageTo'))"]).each { |lang| @to_languages << [lang.name, lang.id] }
    @to_languages << ['----', 0]
    Language.where(["(languages.major=0) AND NOT EXISTS (SELECT * FROM translator_languages WHERE (translator_languages.translator_id=#{@user.id}) AND (translator_languages.language_id=languages.id) AND (translator_languages.type='TranslatorLanguageTo'))"]).each { |lang| @to_languages << [lang.name, lang.id] }
  end

  def set_source
    # set the project type
    project_type = find_user_source(@auser.source)

    if (project_type == 'iphone') || (project_type == 'android') || (project_type == 'software')
      @objective = project_type == 'iphone' ? 'iPhone Localization' : (project_type == 'android' ? _('Android Localization') : _('Software Localization'))
      @next_steps = [[_('Set up your project'), _("Upload your application's resource files.  Our system will parse it and get the texts for translation.")],
                     [_('Deposit payment'), _('The translators you choose will get to work on your project. Translators can handle about 1500 words per day.')],
                     [_('Download the translations'), _('As soon as translation is complete, you can download it and use in the application.')]]
    elsif (project_type == 'drupal') || (project_type == 'wordpress')
      if project_type == 'drupal'
        module_name = 'Translation Management'
        module_type = 'Module'
        @objective = _('Translate Drupal Site')
      else
        module_name = 'WPML'
        module_type = 'plugin'
        @objective = _('Translate WordPress Site')
      end
      @next_steps = [[_('Install %s') % module_name, _('Our translation %s takes care of sending us contents and receiving completed translations.') % module_type],
                     [_('Send us contents'), _('Use the Translation Dashboard in your CMS to choose what to translate and send to us. A single click is all it takes.')],
                     [_('Deposit payment'), _('The translators you choose will get to work on your project. Translators can handle about 1500 words per day.')],
                     [_('Receive the translations'), _('As soon as translations complete, they appear back in your CMS, ready for publishing.')]]
    elsif project_type == 'html'
      @next_steps = [[_('Set up a project'), _('Use our translation software to extract all texts from your website and upload to us for translation.')],
                     [_('Deposit payment'), _('The translators you choose will get to work on your project. Translators can handle about 1500 words per day.')],
                     [_('Receive the translations'), _('As soon as translations complete, you can download them. Our translation software will create your completed website, ready for publishing.')]]
      @objective = _('Translate HTML Website')
    elsif project_type == 'hm'
      @next_steps = [[_('Set up a project'), _('Use our translation software to extract all texts from your Help &amp; Manual project and upload to us for translation.')],
                     [_('Deposit payment'), _('The translators you choose will get to work on your project. Translators can handle about 1500 words per day.')],
                     [_('Receive the translations'), _('As soon as translations complete, you can download them. Our translation software will create your completed Help &amp; Manual projects, ready for publishing.')]]
      @objective = _('Translate Help &amp; Manual Projects')
    elsif project_type == 'affiliate'
      @next_steps = [[_('Get affiliate link'), _('Get your unique affiliate link, by which we can identify new clients that you help bring.')],
                     [_('Get paid'), _('We will credit you for every job that comes in through your affiliate link. We pay with PayPal')]]
      @objective = _('Translate Help &amp; Manual Projects')
    else
      @next_steps = [[_('Set up a project'), _('You can create translation projects for websites, desktop software, mobile apps and office documents.')],
                     [_('Deposit payment'), _('The translators you choose will get to work on your project. Translators can handle about 1500 words per day.')],
                     [_('Receive the translations'), _('As soon as translations complete, you can download them.')]]
      @objective = _('Translation Project')
    end
  end

  def setup_captch_image
    @captcha_image = CaptchaImage.new(content_type: 'image/jpeg', filename: 'captcha.jpg')
    @captcha_image.generate_image
  end

end
