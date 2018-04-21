class WebsitesController < ApplicationController
  include ::AuthenticateProject
  include ::ReuseHelpers
  include ::UpdateSupporterDataAction
  include ::ValidateCmsAccess
  include ::WebsitesTestXmlRpc

  # disable CSRF token check to be able to accept requests from WPML
  skip_before_action :verify_authenticity_token

  prepend_before_action :locate_website, except: [:searcher, :show, :index, :new, :create, :cms_requests, :create_by_cms, :validate_affiliate, :translators, :new_user, :custom_text, :translator_chat, :language_pair, :ts_quote, :token]
  prepend_before_action :setup_user, except: [:show, :create, :create_by_cms, :validate_affiliate, :translators, :new_user, :custom_text, :ts_quote, :token]

  before_action :verify_client, except: [:show, :create, :create_by_cms, :validate_affiliate, :translators, :new_user, :custom_text, :translator_chat, :language_pair, :ts_quote, :token, :confirm_resignation, :confirmed_resignation, :cancel_resignation, :reveal_wp_credentials]
  before_action :verify_admin, only: [:update, :close_all, :update_supporter_data]
  before_action :setup_help, except: [:show, :create, :create_by_cms, :validate_affiliate, :translators, :new_user, :custom_text, :translator_chat, :language_pair, :ts_quote, :token, :reveal_wp_credentials]
  layout :determine_layout
  before_action :verify_modify, only: %w(edit_description)

  TM_COMPLETE_TEXT = { TM_COMPLETE_MATCHES => N_('Apply translation memory and mark matches as complete'),
                       TM_PENDING_MATCHES => N_('Apply translation memory but do not mark matches as complete'),
                       TM_IGNORE_MATCHES => N_('Do not apply translation memory') }.freeze

  def index
    # Redirect and preserve params (e.g., accesskey)
    redirect_to controller: '/wpml/websites', action: 'index', params: params
  end

  def searcher
    params[:page] ||= 1
    params[:per_page] = 5
    session[:last_ajax_page] = params[:page]
    @websites = params[:project_filter].present? ? @user.websites.where('websites.name LIKE ?', "%#{params[:project_filter]}%").page(params[:page]).per(PER_PAGE_SUMMARY) : @user.websites.page(params[:page]).per(params[:per_page])
    @websites_message = if @websites.total_pages > 1
                          _('Page %d of %d of CMS translation projects') % [@websites.current_page, @websites.total_pages] +
                            "&nbsp;&nbsp;&nbsp;<a href=\"#{url_for(controller: '/wpml/websites', action: :index)}\">" + _('Summary of all CMS translation projects') + '</a>'
                        else
                          _('Showing all your CMS translation projects')
                        end
  end

  def new
    @header = _('Create a new CMS translation project')
  end

  def create
    head :not_acceptable unless request.format == Mime[:json]

    params[:project] ||= {}
    if params[:project][:delivery_method]
      params[:project][:pickup_type] = if params[:project][:delivery_method].casecmp('xmlrpc').zero?
                                         0
                                       else
                                         1
                                       end
      params[:project].delete(:delivery_method)
    end

    if params[:api_version] == '2.0' # WPML 3.9
      api_key = request.headers['HTTP_AUTHORIZATION']
      raise ApplicationController::NotAuthorized unless api_key.present?
      client = Client.find_by_api_key(api_key.sub('ApiToken ', '').strip)
      raise ApplicationController::NotAuthorized unless client.present?
      @website = Website.new(params[:project].merge(
                               api_version: '2.0',
                               cms_kind: 1
      ))
      @website.client = client
    else
      @website = Website.new(params[:project].merge(
                               api_version: '1.0',
                               cms_kind: 1,
                               anon: 1
      ))
    end
    @website.dummy = params[:project].include?(:dummy)
    raise Website::NotCreated, @website unless @website.valid?
    @website.save!

    if params[:affiliate]
      @website.set_affiliate(params[:affiliate][:id], params[:affiliate][:key])
    end

    respond_to do |format|
      format.json
    end
  end

  def dummy_response
    response = {
      "status": {
        "code": 0,
        "message": 'success'
      },
      "response": [
        {
          "format_string": 'Jobs sent to ICanLocalize: 9008 - %s',
          "links": [
            {
              "text": 'view jobs',
              "url": "https://www.icanlocalize.com/websites/1083/cms_requests?accesskey=d496c749a50a9bc56f8ba22e6bbd9b0b\u0026compact=1"
            }
          ]
        },
        {
          "format_string": "Your balance at ICanLocalize is 10951.26 USD. Planned expenses: 9243.57 USD.\n Available balance: 1707.69 USD. Visit your %s page to make a new deposit.",
          "links": [
            {
              "text": 'ICanLocalize finance',
              "url": "https://www.icanlocalize.com/finance?accesskey=d496c749a50a9bc56f8ba22e6bbd9b0b\u0026compact=1\u0026wid=1083"
            }
          ]
        },
        {
          "format_string": 'For any help with this project, visit the %s',
          "links": [
            {
              "text": 'support center',
              "url": "https://www.icanlocalize.com/support?accesskey=d496c749a50a9bc56f8ba22e6bbd9b0b\u0026compact=1\u0026wid=1083"
            }
          ]
        }
      ]
    }
    render json: response.to_json
  end

  def custom_text
    head(:not_acceptable) && return unless request.format == Mime[:json]

    begin
      @website = authenticate_project
    rescue AuthorizationError, InvalidParams => e
      logger.info "ERROR #{e} websites#custom_text #{e.message}"
      head(:unauthorized) && return
    end

    @location = params[:location]
    case @location
    when 'dashboard'
      money_account = @website.client.find_or_create_account(DEFAULT_CURRENCY_ID)
      @account_total = money_account.balance
      @planned_expenses = money_account.pending_total_expenses[0]
      @balance = @account_total - @planned_expenses
      @missing_amount = @website.missing_amount
    when 'translators'
      # Nothing is needed apart from @website
    when 'reminders'
      @reminders = @website.reminders.where('normal_user_id=?', @website.client.id).order('reminders.id DESC')
      @missing_amount = @website.missing_amount
    when 'string_translation'
      # nothing is needed apart from @website
    else
      raise InvalidParams, 'location'
    end

    respond_to do |format|
      format.json
    end
  end

  def reuse_translators
    if @website.website_translation_offers.empty?
      flash[:notice] = 'You did not add languages yet.'
      redirect_to :back
      return
    end

    project_hash = JSON.parse(params[:project])
    project_to_reuse = project_hash['class'].constantize.find(project_hash['id'])

    translator_for_language = languages_and_translators_to_reuse(project_to_reuse)
    reviewer_for_language = languages_and_reviewers_to_reuse(project_to_reuse)

    missing_wtos = @website.website_translation_offers.find_all { |wto| wto.accepted_website_translation_contracts.empty? }

    flash[:notice] = ''
    missing_wtos.each do |wto|
      translator = translator_for_language[wto.to_language]
      reviewer = reviewer_for_language[wto.language]
      next unless translator
      if wto.managed_work && wto.managed_work.translator_id == translator.id
        wto.managed_work.update_attribute :translator_id, nil
      end

      wto.set_reviewer(reviewer) if reviewer

      wtc = @website.website_translation_contracts.find_by(translator_id: translator.id)
      unless wtc
        wtc = WebsiteTranslationContract.new(status: TRANSLATION_CONTRACT_NOT_REQUESTED, currency_id: DEFAULT_CURRENCY_ID)
        wtc.website_translation_offer = wto
        wtc.translator = translator
        wtc.save!

        message = Message.new(
          body: "Hi, I'm inviting you to join me in this project.
            Since we already worked together on #{project_to_reuse.name}, I'd like you to bid on this project, please.",
          chgtime: Time.now
        )

        message.user = @website.client
        message.owner = wtc
        message.save!

        if translator.can_receive_emails?
          ReminderMailer.new_message_for_cms_translation(translator, wtc, message).deliver_now
        end
      end
      flash[:notice] += "#{translator.nickname} was invited to be your #{wto.to_language.name} translator\n"
    end
    flash[:notice] = 'Could not find any translator to reuse' if flash[:notice].blank?

    redirect_to :back
  end

  def migrate
    if request.format == Mime[:json]
      @website = authenticate_project
      raise Website::NotFound unless @website
      params_to_update = { migrated_to_tp: 1, pickup_type: PICKUP_BY_POLLING, api_version: '1.0' }
      @website.update_attributes(params_to_update)
    end

    respond_to do |format|
      format.json { render action: :create }
    end
  end

  def show
    # This action no longer has an HTML view. It should only be used for json
    # and xml requests.
    if request.format == Mime[:html]
      # Redirect and preserve params (e.g., accesskey)
      redirect_to controller: '/wpml/websites', action: 'show', params: params
      return
    end

    if request.format == Mime[:json]
      @website = authenticate_project
      raise Website::NotFound unless @website
      @translator_per_language_pair = @website.website_translation_offers.group_by do |x|
        { to: x.to_language.name,
          from: x.from_language.name }
      end
    else
      setup_user
      return unless @user
      return unless locate_website
      return unless verify_client
      return unless verify_view

      setup_navigation

      # projects_to_reuse is implemented in ReuseHelpers
      @projects_to_reuse = projects_to_reuse if @user.has_client_privileges?

      @header = @website.name

      tas_mode = (params[:tas_mode].to_i == 1)

      # things that only the client can see
      if @user.is_client? || @user.has_supporter_privileges?
        # check for low balance
        @money_account = @website.client.find_or_create_account(DEFAULT_CURRENCY_ID)
        if tas_mode
          @missing_funds = 0
        else
          @missing_funds = @website.missing_amount
          if @missing_funds > 0
            @uncompleted_requests = @website.processed_pending_cms_requests
          end
        end

        @account_total = @money_account.balance
        @planned_expenses = @money_account.pending_total_expenses[0]
        @balance = @account_total - @planned_expenses

        # check if the accesskey needs to update
        @accesskey_needs_update = (@website.accesskey_ok != ACCESSKEY_VALIDATED)

        if tas_mode
          @cms_requests_length = 0
          @error_cms_requests_length = 0
        else
          # list the cms requests
          @cms_requests_length = @website.cms_requests.count

          # check for problematic cms requests
          @error_cms_requests_length = @website.cms_requests.where('pending_tas=1').count
        end
      end
    end

    @support_ticket_id = @website.support_ticket ? @website.support_ticket.id : nil

    respond_to do |format|
      format.xml
      format.json
    end
  end

  def close_all
    @website.website_translation_offers.each do |website_translation_offer|
      website_translation_offer.update_attributes!(status: TRANSLATION_OFFER_CLOSED)
    end
    flash[:notice] = _('Closed all offers for this website')
    redirect_to action: :show
  end

  def get
    @cms_container = @website.cms_container
    unless @cms_container
      set_err('Cannot find this file')
      return
    end

    respond_to do |format|
      format.html { send_file(@cms_container.full_filename) }
      format.xml
    end

  end

  def store
    cms_container = @website.cms_container

    if !cms_container
      created_ok = false
      begin
        cms_container = CmsContainer.new(params[:cms_container])
        cms_container.website = @website
        cms_container.user = @user
        created_ok = true
      rescue ActiveRecord::RecordInvalid
        @result = { 'message' => 'Container failed' }
      end

      if created_ok
        @result = if cms_container.save
                    { 'message' => 'Container created', 'id' => cms_container.id }
                  else
                    { 'message' => 'Container cannot be saved' }
                  end
      end
    else
      new_params = params[:cms_container].merge(chgtime: Time.now)
      if cms_container.update_attributes(new_params)
        @result = { 'message' => 'Container updated', 'id' => cms_container.id }
      end
    end

    respond_to do |format|
      format.html
      format.xml
    end
  end

  def create_message
    if @orig_user
      flash[:notice] = "you can't post a message while logged in as other user"
      redirect_to :back
      return
    end
    if params[:body].blank?
      set_err('Body cannot be blank')
      return
    end
    body = Base64.decode64(params[:body])

    from_language = Language.where('name=?', params[:from_language]).first
    unless from_language
      set_err('Source language not specified or invalid')
      return
    end

    to_language = Language.where('name=?', params[:to_language]).first
    unless to_language
      set_err('Destination language not specified or invalid')
      return
    end
    if from_language == to_language
      set_err('Source and destination languages cannot be the same')
      return
    end

    expected_signature = Digest::MD5.hexdigest(body + params[:from_language] + params[:to_language])
    signature = params[:signature]
    if expected_signature != signature
      set_err('Signature does not match')
      return
    end

    website_translation_offer = @website.website_translation_offers.where('(from_language_id=?) AND (to_language_id=?)', from_language.id, to_language.id)
    if website_translation_offer
      asian_language = Language.asian_language_ids.include?(from_language.id)
      word_count = asian_language ? (body.length / UTF8_ASIAN_WORDS).ceil : body.split_text.length

      web_message = WebMessage.new(visitor_body: body,
                                   visitor_language_id: from_language.id,
                                   client_language_id: to_language.id,
                                   create_time: Time.now,
                                   word_count: word_count,
                                   money_account: @user.find_or_create_account(DEFAULT_CURRENCY_ID),
                                   translation_status: TRANSLATION_NEEDED,
                                   comment: 'This message is a comment left on a website',
                                   notified: 0)
      web_message.owner = @website
      @result = if web_message.save!
                  { 'message' => 'Message created', 'id' => web_message.id }
                else
                  { 'message' => 'Message cannot be created' }
                end
    else
      @result = { 'message' => 'Cannot translate between these languages' }
    end

    respond_to do |format|
      format.html
      format.xml
    end

  end

  def edit_description
    req = params[:req]
    if req == 'show'
      @editing = true
      @platforms = WEBSITE_DESCRIPTION.collect { |k, v| [v, k] }
    elsif req.nil?
      @warning = validate_cms_access(params[:website], @website.platform_kind, true, params[:website][:pickup_type].to_i, @website)
      @website.update_attributes!(params[:website]) if @warning.nil?
    end
  end

  def links
    @link_map = {}
    @website.cms_requests.includes(:cms_target_languages).each do |cms_request|
      link_res = {}
      cms_request.cms_target_languages.each do |cms_target_language|
        if cms_target_language.permlink
          link_res[cms_target_language.language_id] = [cms_target_language.permlink, cms_target_language.title]
        end
      end
      @link_map[cms_request] = link_res if link_res != {}
    end
    respond_to do |format|
      format.html
      format.xml
    end
  end

  def flush_requests
    if %w(sandbox development).include?(Rails.env)
      CmsRequest.record_timestamps = false
      t = Time.now - 5 * DAY_IN_SECONDS
      @website.cms_requests.where('(list_type IS NOT NULL) AND (status=?)', CMS_REQUEST_RELEASED_TO_TRANSLATORS).each { |c| c.update_attributes(updated_at: t) }
      CmsRequest.record_timestamps = true
    end
    flash[:notice] = 'Made all cms_requests old'
    redirect_to action: :show
  end

  def all_comm_errors

    @header = _('All communication errors')

    if @user.can_modify?(@website)
      @cms_requests = @website.error_cms_requests.order('cms_requests.id ASC')
    else
      set_err('You are not allowed to view this page.')
      return
    end
    respond_to do |format|
      format.html
      format.xml
    end
  end

  def search_cms
    #  return {:search => @search, :cms_requests => @cms_requests, :list_of_pages => @list_of_pages, :error => @error}
    sc = SearchController.new
    ret = sc.cms_search(@user, params)
    if ret.is_a? Hash
      @search = ret[:search]
      @cms_requests = ret[:cms_requests]
      @list_of_pages = ret[:list_of_pages]
      @error = ret[:error]
    end
  end

  def cms_requests
    @header = _('Summary of all translation jobs')

    cms_requests = @user.cms_requests

    @pager = ::Paginator.new(cms_requests.count, PER_PAGE) do |offset, per_page|
      @user.cms_requests.limit(per_page).offset(offset).order('cms_requests.id DESC')
    end

    page = params[:page].to_i

    @cms_requests = @pager.page(params[:page])
    @list_of_pages = []
    for idx in 1..@pager.number_of_pages
      @list_of_pages << idx
    end

    if !page || (page < 2)
      # create all statistics
      complete_cnt = 0
      pending_cnt = 0
      processing_cnt = 0
      pending_word_count = {}
      @user.cms_requests.each do |c|
        if c.status <= CMS_REQUEST_CREATING_PROJECT
          processing_cnt += 1
        elsif (c.status == CMS_REQUEST_TRANSLATED) || (c.status == CMS_REQUEST_DONE)
          complete_cnt += 1
        else
          pending_cnt += 1
          c.cms_target_languages.each do |cms_target_language|
            next if cms_target_language.word_count.nil?
            lang_pair = [c.language, cms_target_language.language]
            unless pending_word_count.key?(lang_pair)
              pending_word_count[lang_pair] = 0
            end
            pending_word_count[lang_pair] += cms_target_language.word_count
          end
        end
      end
      @statistics = [[_('Translation completed'), complete_cnt], [_('Waiting to be translated'), pending_cnt], [_('Processing'), processing_cnt]]
      unless pending_word_count.empty?
        pending_word_count.each do |k, v|
          @statistics << [_('Pending %s to %s words') % [k[0].name, k[1].name], v]
        end
      end
    end
  end

  def destroy
    redirect_link = url_for controller: :supporter, action: :cms_projects
    redirect_link = url_for controller: '/wpml/websites', action: :index unless %w(Admin Support).include? @user.type
    if @website.can_delete? && @user.has_supporter_privileges?
      @website.destroy
      flash[:notice] = _('CMS translation project deleted')
    else
      flash[:notice] = _('Project deletion failed, you are not authorize to delete this project, please contact support')
    end
    redirect_to redirect_link
  end

  def web_messages_for_pickup
    @web_messages = @website.web_messages.where('(translation_status=?)', TRANSLATION_NOT_DELIVERED)
    respond_to do |format|
      format.html
      format.xml
    end
  end

  def ack_message_pickup
    last_id = params[:last_id].to_i
    if last_id == 0
      set_err('last_id parameter must be specified')
      return
    end

    @updated_messages_count = 0
    web_messages = @website.web_messages.where('(translation_status=?) AND (id <= ?)', TRANSLATION_NOT_DELIVERED, last_id)
    web_messages.each do |web_message|
      web_message.update_attributes(translation_status: TRANSLATION_COMPLETE)
      @updated_messages_count += 1
    end
    respond_to do |format|
      format.html
      format.xml
    end
  end

  # This is only used by WPML 3.1 and lower (even WPML 2.0!)
  # Still used in Jan 2018 (called 39 times in 15 days)
  def create_by_cms
    # user account parameters
    email = params[:email]
    fname = params[:fname]
    lname = params[:lname]
    create_account = params[:create_account].to_i == 1
    password = params[:password]
    is_verified = !params[:is_verified].blank?
    xmlrpc_path = params[:xmlrpc_path]
    anon = params[:anon].to_i == 1
    word_count = params[:word_count]
    wc_description = params[:wc_description]

    # this cannot be changed later
    platform_kind = params[:platform_kind].to_i
    interview_translators = params[:interview_translators].to_i == 1
    cms_login = params[:cms_login]
    cms_password = params[:cms_password]
    blogid = params[:blogid].to_i

    cms_kind = params[:cms_kind].blank? ? CMS_KIND_DRUPAL : params[:cms_kind].to_i
    cms_description = params[:cms_description]

    # website parameters
    url = params[:url]
    title = params[:title]
    description = params[:description]
    pickup_type = params[:pickup_type].to_i
    notifications = params[:notifications].to_i
    project_kind = anon ? PRODUCTION_CMS_WEBSITE : (params[:project_kind] || PRODUCTION_CMS_WEBSITE.to_s).to_i

    ignore_languages = params[:ignore_languages].to_i == 1

    if params[:url].nil?
      @response_status_code = :unprocessable_entity
      @warning = 'Invalid params'
      set_err(@warning)
      return
    end

    if title.blank?
      title = url.start_with?('https://') ? url[8..-1] : (url.start_with?('http://') ? url[7..-1] : url)
    end

    description = 'Website translation project' if description.blank?

    # affiliate information
    affiliate_id = params[:affiliate_id].to_i
    affiliate_key = params[:affiliate_key]

    if platform_kind == 0
      set_err('Platform kind not specified')
      return
    end

    if email.blank? && !anon
      set_err('User email missing')
      return
    end

    begin
      language_pairs = collect_translation_languages
    rescue => e
      set_err(e.message)
      return
    end

    if !ignore_languages && !(language_pairs && !language_pairs.empty?)
      set_err('No translation language selected')
      return
    end

    if pickup_type == PICKUP_BY_RPC_POST
      unless test_xmlrpc(url, xmlrpc_path)
        set_err('Cannot access via XML-RPC')
        return
      end
    end

    user = User.find_by(email: email) unless email.blank?

    if !create_account && user && (user[:type] == 'Partner')
      user[:type] = 'Client'
      user.save
      user = User.find_by(email: email)
    end

    @warning = nil

    if create_account
      if user
        @warning = 'An account with this email already exists'
      elsif (fname.blank? || lname.blank?) && !anon
        @warning = 'First and last name must be entered'
      else
        lc = params[:lc]
        loc_code = nil

        if anon
          # Milliseconds since epoch
          unique_digits = (Time.now.to_f * 1000).to_i
          user = Client.create!(email: "unreg#{unique_digits}@icanlocalize.com",
                                signup_date: Time.now,
                                fname: "fname#{unique_digits}",
                                lname: "lname#{unique_digits}",
                                nickname: Rails.env == 'test' ? 'testbox_user' : "unreg#{unique_digits}",
                                password: Rails.env == 'test' ? 'testbox_password' : "pw#{unique_digits}",
                                anon: 1,
                                notifications: NEWSLETTER_NOTIFICATION,
                                display_options: DISPLAY_AFFILIATE,
                                source: "CMS #{CMS_DESCRIPTION[cms_kind]}",
                                loc_code: loc_code)
        else
          nickname = email[0...email.index('@')]
          nickname_cnt = User.where('nickname LIKE ?', "#{nickname}%").count
          nickname += (nickname_cnt + 1).to_s
          idx = 1
          base_nickname = nickname
          while User.where('nickname = ?', nickname).count != 0
            nickname = base_nickname + idx.to_s
            idx += 1
          end
          password = Digest::MD5.hexdigest(Time.now.to_s)[0...8].tr('0', '9').tr('1', '3')

          userstatus = is_verified ? USER_STATUS_REGISTERED : USER_STATUS_NEW

          user = Client.new(email: email, nickname: Rails.env == 'test' ? 'testbox2_user' : nickname,
                            fname: fname, lname: lname, userstatus: userstatus,
                            password: Rails.env == 'test' ? 'testbox2_password' : password, signup_date: Time.now,
                            notifications: NEWSLETTER_NOTIFICATION,
                            display_options: DISPLAY_AFFILIATE,
                            source: "CMS #{CMS_DESCRIPTION[cms_kind]}",
                            loc_code: loc_code)

          unless user.save
            errors = (user.errors.full_messages.collect { |msg| " * #{msg}" }).join("\n")
            set_err("Could not create this account because:\n#{errors}")
            return
          end

          user.reload
        end

        # check if we need to set the affiliate information for this account
        if (affiliate_id != 0) && affiliate_key
          begin
            affiliate = User.find(affiliate_id)
          rescue
            affiliate = nil
          end
          if affiliate && (affiliate.affiliate_key == affiliate_key)
            user.affiliate = affiliate
            user.save
          end
        end

        # create money account if required
        user.get_money_account

      end
    elsif !create_account && (!user || (user.get_password != password))
      @warning = 'Incorrect password or email for this account'
    end

    if @warning
      set_err(@warning)
      return
    end

    # we now have a user and can create the project and add languages
    @website = Website.new(name: title, description: description, platform_kind: platform_kind,
                           url: url, login: cms_login, password: cms_password,
                           blogid: blogid, pickup_type: pickup_type,
                           interview_translators: interview_translators,
                           notifications: notifications,
                           project_kind: project_kind,
                           cms_kind: cms_kind,
                           cms_description: cms_description,
                           xmlrpc_path: xmlrpc_path,
                           free_support: (!ignore_languages || anon ? 1 : 0),
                           anon: (anon ? 1 : 0))

    if !word_count.blank? && !wc_description.blank?
      @website.word_count = word_count.to_i
      @website.wc_description = wc_description
    end

    @website.client = user
    unless @website.save
      # if we just created the user account, destroy it
      user.destroy if create_account
      errors = (@website.errors.full_messages.collect { |msg| " * #{msg}" }).join("\n")
      set_err("Could not create this project because:\n#{errors}")
      return
    end

    unless ignore_languages
      # create the translation offers
      language_pairs.each do |language_pair|

        from_language = language_pair[0]
        to_language = language_pair[1]

        status = anon ? TRANSLATION_OFFER_CLOSED : TRANSLATION_OFFER_OPEN

        offer = WebsiteTranslationOffer.create!(
          website_id: @website.id,
          from_language_id: from_language.id,
          to_language_id: to_language.id,
          url: url,
          login: cms_login,
          password: cms_password,
          status: status,
          notified: 0,
          # The WPML versions that use this action (3.1 and lower) have no
          # support for automatic translator assignment, which is only available
          # for WPML 3.8+
          automatic_translator_assignment: false
        )

        ManagedWork.create!(
          active: MANAGED_WORK_INACTIVE,
          from_language: offer.from_language,
          to_language: offer.to_language,
          client: offer.website.client,
          owner: offer
        )
      end
    end

    if create_account && !anon
      if !is_verified
        # ReminderMailer.user_should_complete_registration(user, "Your password, required for logging in is:\n#{password}\n").deliver_now
      else
        control_screen = cms_kind == CMS_KIND_WORDPRESS ? 'WPML -> Pro translation' : 'ICanLocalize setup'
        # ReminderMailer.welcome_cms_user(user, control_screen).deliver_now
      end
    end

    respond_to do |format|
      format.html
      format.xml { render action: :show }
    end
  end

  # This is used by many WPML versions, from 2.0.4.1 (that's right) to 3.8.4
  # Still used in Jan 2018 (called 18 times in 15 days). It's triggered when
  # the client does the following in WP: 'WPML' -> 'Translation Management' ->
  # 'Translators' tab - > 'Edit languages' (in the 'IcanLocalize' row of the
  # 'Current translators' table) -> select or deselect a language -> 'Update'
  # button.
  def update_by_cms
    # website parameters
    url = params[:url]
    title = params[:title]
    description = params[:description]
    pickup_type_s = params[:pickup_type]
    notifications_s = params[:notifications]
    project_kind_s = params[:project_kind]
    interview_translators_s = params[:interview_translators]
    word_count = params[:word_count]
    wc_description = params[:wc_description]

    ignore_languages = params[:ignore_languages].to_i == 1

    begin
      language_pairs = collect_translation_languages
    rescue => e
      set_err(e.message)
      return
    end
    return false if !language_pairs && !ignore_languages

    # affiliate information
    affiliate_id = params[:affiliate_id].to_i
    affiliate_key = params[:affiliate_key]

    params_to_update = {}
    params_to_update[:url] = url if url
    params_to_update[:name] = title if title
    params_to_update[:description] = description if description
    params_to_update[:pickup_type] = pickup_type_s.to_i if pickup_type_s
    params_to_update[:notifications] = notifications_s.to_i if notifications_s
    # if project_kind_s
    # params_to_update[:project_kind] = project_kind_s.to_i
    # end
    if interview_translators_s
      params_to_update[:interview_translators] = interview_translators_s.to_i
    end
    params_to_update[:free_support] = 1 unless ignore_languages

    if !word_count.blank? && !wc_description.blank?
      @website.word_count = word_count.to_i
      @website.wc_description = wc_description
    end

    # update the website attributes
    @website.update_attributes(params_to_update)

    unless ignore_languages
      # create missing translation offers
      language_pairs.each do |language_pair|
        from_language = language_pair[0]
        to_language = language_pair[1]

        @website.find_or_create_offer(from_language, to_language)
      end
    end
    # check for new affiliate ID

    # check if we need to update the affiliate information for this account
    if !@website.client.affiliate && (affiliate_id != 0) && affiliate_key
      begin
        affiliate = User.find(affiliate_id)
      rescue
        affiliate = nil
      end
      if affiliate && (affiliate.affiliate_key == affiliate_key)
        @website.client.affiliate = affiliate
        @website.client.save
      end
    end

    respond_to do |format|
      format.html
      format.xml { render action: :show }
    end
  end

  def request_transfer_account
    @header = _('Transfer this project to a different account')
  end

  def transfer_account
    # user account parameters
    email = params[:email]
    fname = params[:fname]
    lname = params[:lname]
    create_account = params[:create_account].to_i == 1
    password = params[:password]

    # affiliate information
    affiliate_id = params[:affiliate_id].to_i
    affiliate_key = params[:affiliate_key]

    user = User.find_by(email: email)

    if !create_account && user && (user[:type] == 'Partner')
      user[:type] = 'Client'
      user.save
      user = User.find_by(email: email)
    end

    @warning = nil

    if create_account
      if user
        @warning = 'An account with this email already exists'
      elsif fname.blank? || lname.blank?
        @warning = 'First and last name must be entered'
      else
        nickname = email[0...email.index('@')]
        nickname_cnt = User.where('nickname LIKE ?', "#{nickname}%").count
        nickname += (nickname_cnt + 1).to_s
        idx = 1
        base_nickname = nickname
        while User.where('nickname = ?', nickname).count != 0
          nickname = base_nickname + idx.to_s
          idx += 1
        end
        password = Digest::MD5.hexdigest(Time.now.to_s)[0...8].tr('0', '9').tr('1', '3')

        user = Client.new(email: email, nickname: nickname,
                          fname: fname, lname: lname, userstatus: USER_STATUS_REGISTERED,
                          password: password, signup_date: Time.now,
                          display_options: DISPLAY_AFFILIATE,
                          source: "CMS transfer of project #{@website.id}",
                          loc_code: DEFAULT_LOCALE)

        # check if we need to set the affiliate information for this account
        if (affiliate_id != 0) && affiliate_key
          begin
            affiliate = User.find(affiliate_id)
          rescue
            affiliate = nil
          end
          if affiliate && (affiliate.affiliate_key == affiliate_key)
            user.affiliate = affiliate
          end
        end

        unless user.save
          errors = (user.errors.full_messages.collect { |msg| " * #{msg}" }).join("\n")
          set_err("Could not create this account because:\n#{errors}")
          return
        end

        user.reload

        money_account = UserAccount.new(balance: 0, currency_id: DEFAULT_CURRENCY_ID)
        money_account.normal_user = user
        money_account.save!

      end
    elsif !create_account && (!user || (user.get_password != password))
      logger.info '---------------- Incorrect password or email for this account'
      if user
        @warning = 'Incorrect password for this account'
        logger.info "------------------- user = #{user.email}, password=#{user.get_password}"
      else
        @warning = "Account with this email #{email} doesn't exist."
        logger.info '------------------- no user'
      end
    end

    if user && user[:type] != 'Client'
      @warning = _('You can only transfer the project to a client. Not to a %s.') % user[:type]
    end

    # transfer the account if there's no warning
    unless @warning
      logger.info "------------------- @website = #{@website.id}"
      logger.info "------------------- @website.client = #{@website.client}"
      logger.info "------------------- @website.client.id = #{@website.client.id}"
      old_client_id = @website.client.id

      @website.free_support = 1
      @website.client = user
      @website.save

      money_account = user.money_accounts[0]

      @website.cms_requests.each do |cms_request|
        cms_request.cms_target_languages.each do |cms_target_language|
          cms_target_language.money_account = money_account
          cms_target_language.save
        end

        revision = cms_request.revision

        next unless revision
        revision.project.client = user
        revision.project.save

        revision.versions.where('by_user_id=?', old_client_id).each do |version|
          version.update_attributes(by_user_id: user.id)
        end
      end

      if create_account
        control_screen = @website.cms_kind == CMS_KIND_WORDPRESS ? 'WPML -> Pro translation' : 'ICanLocalize setup'
        if user.can_receive_emails?
          ReminderMailer.welcome_cms_user(user, control_screen).deliver_now
        end
      end
    end

    respond_to do |format|
      format.html do
        if @warning
          flash[:notice] = @warning
          redirect_to(action: :request_transfer_account)
        else
          flash[:notice] = _('The project now belongs to user %s') % user.nickname
          redirect_to(action: :index)
        end
      end
      format.xml do
        if @warning
          set_err(@warning)
        else
          render action: :show
        end
      end
    end
  end

  def validate_affiliate
    # affiliate information
    affiliate_id = params[:affiliate_id].to_i
    affiliate_key = params[:affiliate_key]

    @result = 'ERROR'

    if (affiliate_id != 0) && affiliate_key
      begin
        affiliate = User.find(affiliate_id)
      rescue
        affiliate = nil
      end
      @result = 'OK' if affiliate && (affiliate.affiliate_key == affiliate_key)
    end

    respond_to do |format|
      format.html { render plain: @result }
      format.xml
    end
  end

  def update
    @website.assign_attributes(params[:website])
    if @website.valid?
      @website.save
      flash[:notice] = 'Updated website parameters'
    else
      flash[:notice] = @website.errors.full_messages.join('<br />')
    end
    redirect_to action: :show
  end

  def explain
    if @website.support_ticket
      flash[:notice] = 'A support ticket for this website already exists'
      redirect_to controller: :support, action: :show, id: @website.support_ticket
      return
    end

    @header = _('Tell us about this site')

  end

  def create_explanation
    body = params[:body]
    if body.blank?
      flash[:notice] = _('Please enter a description for your website')
      redirect_to action: :explain
    else
      support_ticket = SupportTicket.new(subject: 'Information about website %s' % @website.name)
      support_ticket.normal_user = @user
      support_ticket.support_department = SupportDepartment.find_by(name: SETUP_PROJECT_REQUEST)
      support_ticket.status = SUPPORT_TICKET_CREATED
      support_ticket.create_time = Time.new
      support_ticket.object = @website
      support_ticket.message = body
      support_ticket.save!

      message = Message.new(body: body)
      message.owner = support_ticket
      message.user = @user
      message.chgtime = Time.now
      message.save!

      flash[:notice] = _('Thanks for the info. We will update you soon when there are news. Below is the support ticket we opened for your website.')
      redirect_to controller: :support, action: :show, id: support_ticket.id
    end
  end

  def new_ticket
    @header = _('Create a new support ticket')
  end

  def create_ticket
    @subject = params[:subject]
    @body = params[:body]

    @problems = []

    @problems << _('Please enter the subject') if @subject.blank?

    @problems << _('Please enter the ticket details') if @body.blank?

    if !@problems.empty?
      @header = _('Create a new support ticket')
      render action: :new_ticket
    else
      support_ticket = SupportTicket.new(subject: @subject)
      support_ticket.normal_user = @user
      support_ticket.support_department = SupportDepartment.find_by(name: CMS_SUPPORT_DEPARTMENT)
      support_ticket.status = SUPPORT_TICKET_CREATED
      support_ticket.create_time = Time.new
      support_ticket.object = @website
      support_ticket.message = @body
      support_ticket.save!

      message = Message.new(body: @body)
      message.owner = support_ticket
      message.user = @user
      message.chgtime = Time.now
      message.save!

      admins = Admin.all
      wpml = User.find_by(nickname: 'WPML')
      admins << wpml if wpml

      ReminderMailer.notify_support_about_new_ticket(admins.map(&:email), support_ticket).deliver_now

      flash[:notice] = _('We will get back to you shortly. Below is the support ticket we opened for your website.')
      redirect_to controller: :support, action: :show, id: support_ticket.id
    end
  end

  def translators
    @source_lang_id = params[:source_lang_id].to_i
    @target_lang_id = params[:target_lang_id].to_i

    begin
      @source_lang = Language.find(@source_lang_id)
    rescue
      @source_lang = nil
    end

    begin
      @target_lang = Language.find(@target_lang_id)
    rescue
      @target_lang = nil
    end

    if !@source_lang || !@target_lang
      @header = _('Find a user')
      @warning = _('Please select both source and destination languages')
      @languages = Language.list_major_first
      render action: :translators
      return
    end

    @translators = Translator.
                   where("(users.userstatus = ?)
        AND EXISTS(SELECT * FROM translator_languages WHERE ((translator_languages.translator_id = users.id)
        AND (translator_languages.status = ?)
        AND (translator_languages.language_id = ?)
        AND (translator_languages.type = 'TranslatorLanguageFrom')))
        AND EXISTS(SELECT * FROM translator_languages WHERE ((translator_languages.translator_id = users.id)
        AND (translator_languages.status = ?)
        AND (translator_languages.language_id = ?)
        AND (translator_languages.type = 'TranslatorLanguageTo')))",
                         USER_STATUS_QUALIFIED,
                         TRANSLATOR_LANGUAGE_APPROVED,
                         @source_lang_id,
                         TRANSLATOR_LANGUAGE_APPROVED,
                         @target_lang_id).order('users.raw_rating DESC')

    @back = request.referer unless params[:go_back].blank?

    @header = _('Translators from %s to %s') % [@source_lang.name, @target_lang.name]

  end

  def add_counts
    idx = 1
    cont = true
    to_add = []

    num_elements = params[:num_elements].to_i

    if num_elements <= 0
      set_err('num_elements must be positive')
      return
    end

    while cont
      offer_id = params["offer_id#{idx}"]
      kind = params["kind#{idx}"]
      status = params["status#{idx}"]
      count = params["count#{idx}"]
      service = params["service#{idx}"]
      priority = params["priority#{idx}"]
      code = params["code#{idx}"]
      translator_name = params["translator_name#{idx}"]
      if offer_id && kind && status && count
        to_add << [offer_id.to_i, kind.to_i, status.to_i, count.to_i, service, priority.to_i, code, translator_name]
        idx += 1
      else
        cont = false
      end
    end

    if to_add.length != num_elements
      set_err('number of actual elements (%d) is different than num_elements (%d)' % [to_add.length, num_elements])
      return
    end

    cms_count_group = CmsCountGroup.new
    cms_count_group.website = @website
    cms_count_group.save!

    to_add.each do |count_data|
      cms_count = CmsCount.new(website_translation_offer_id: count_data[0],
                               kind: count_data[1],
                               status: count_data[2],
                               count: count_data[3],
                               service: count_data[4],
                               priority: count_data[5],
                               code: count_data[6],
                               translator_name: count_data[7])
      cms_count.cms_count_group = cms_count_group
      cms_count.save!
    end

    @added = num_elements

    respond_to do |format|
      format.html
      format.xml
    end

  end

  def ts_quote
    @name = params[:website_name]
    @description = params[:description]
    @word_count = params[:word_count].to_i
    @source_language = Language.find_by(name: params[:source_language])
    lang_names = params.select { |k, _v| k.to_s.match(/^target_language\d+/) }.map { |pair| pair[1] }
    @target_languages = lang_names.map { |x| Language.find_by(name: x) }
    @target_languages.delete_if(&:nil?)

    @total_cost = 0
    @cost_per_language = {}
    @target_languages.each do |to_language|
      average_amount = nil
      # find recently accespted contracts
      accepted_contracts =
        WebsiteTranslationContract.joins(:website_translation_offer).
        limit(5).
        where('(website_translation_offers.from_language_id=?) AND (website_translation_offers.to_language_id=?) AND (website_translation_contracts.status=?)', @source_language.id, to_language.id, TRANSLATION_CONTRACT_ACCEPTED).
        order('website_translation_offers.id DESC')

      if !accepted_contracts.empty?
        average_amount = 0
        accepted_contracts.each { |accepted_contract| average_amount += accepted_contract.amount }
        average_amount /= accepted_contracts.length
      else
        average_amount = 0.10
      end

      average_amount = average_amount >= MINIMUM_BID_AMOUNT ? average_amount : MINIMUM_BID_AMOUNT

      @cost_per_language[to_language] = average_amount
      @total_cost += average_amount
    end

    @days_to_complete = (@word_count / 1500.0).ceil.to_i
  end

  def quote
    @header = _('Quote for website translation work from ICanLocalize')

    if !@website.word_count || !@website.wc_description
      set_err('you did not yet request a quote')
      return
    end

    # get the language IDs
    from_language_name = params[:from_language_name]
    @from_language = Language.find_by(name: from_language_name)
    unless @from_language
      set_err('cannot find the source language')
      return
    end

    to_lang_num = params[:to_lang_num].to_i
    if to_lang_num == 0
      set_err('destination languages number not set')
      return
    end

    @to_languages = []
    (1..to_lang_num).each do |idx|
      lang_param_name = "to_language_name_#{idx}"
      to_language = Language.find_by(name: params[lang_param_name])
      unless to_language
        set_err('language %d not specified' % idx)
        return
      end
      @to_languages << to_language
    end

    @total_cost = 0
    @cost_per_language = {}
    @to_languages.each do |to_language|
      average_amount = nil
      # find recently accespted contracts
      accepted_contracts =
        WebsiteTranslationContract.
        includes(:website_translation_offer).
        limit(5).
        order('website_translation_offers.id DESC').
        where('(website_translation_offers.from_language_id=?) AND (website_translation_offers.to_language_id=?) AND (website_translation_contracts.status=?)', @from_language.id, to_language.id, TRANSLATION_CONTRACT_ACCEPTED)

      if !accepted_contracts.empty?
        average_amount = 0
        accepted_contracts.each { |accepted_contract| average_amount += accepted_contract.amount }
        average_amount /= accepted_contracts.length
      else
        average_amount = 0.10
      end

      @cost_per_language[to_language] = average_amount
      @total_cost += average_amount
    end

    @days_to_complete = (@website.word_count / 1500.0).ceil.to_i

    @download = params[:download]
    if @download
      res = render(action: :quote)
      send_data(res,
                filename: 'Quote_from_ICanLocalize.html',
                type: 'text/html',
                disposition: 'downloaded')
    end
  end

  def edit_tm_use
    req = params[:req]
    if req == 'show'
      @editing = true
    elsif req.nil?
      @website.tm_use_mode = params[:tm_use_mode].to_i
      @website.tm_use_threshold = params[:tm_use_threshold].to_i
      @website.save
    end
    @website.reload
  end

  def swap_translators
    unless @user.has_supporter_privileges?
      set_err("you can't do this")
      return
    end

    begin
      source_translator = Translator.find(params[:source_translator_id])
      target_translator = Translator.find_by(nickname: params[:target_nickname])

      raise 'Unknown source translator' unless source_translator
      raise 'Unknown target translator' unless target_translator

      @website.cms_target_languages.where(translator_id: source_translator.id).each do |ctl|
        # Change the owner of the target languages
        ctl.translator_id = target_translator.id
        ctl.save!

        # Transfer the chats - needed to view in TA
        selected_bid = ctl.cms_request.revision.revision_languages.first.try(:selected_bid)
        if selected_bid && selected_bid.chat
          chat = selected_bid.chat
          chat.translator_id = target_translator.id
          chat.save!
        end

        # Transfer the version owners - needed to the new translator get the work from the previous one
        ctl.cms_request.revision.versions.find_all { |v| v.by_user_id == source_translator.id }.each do |version|
          version.by_user_id = target_translator.id
          version.save!
        end
      end
      # Change this translation offer translator
      wtc = @website.website_translation_contracts.find_by(translator_id: source_translator.id)
      wtc.translator_id = target_translator.id
      wtc.save!

    rescue => error
      render html: "<span style='font-weight:bold; color:red;'>Error: #{error}</span>"
    else
      render html: "<span style='font-weight:bold; color:red;'>Assigned to <a href='/users/#{target_translator.id}'>#{target_translator.nickname}</a></span>"
    end
  end

  def create_language_pair
    redirect_to controller: :company, action: :new_language, from_language_id: params[:from_language_id], to_language_id: params[:to_language_id], wid: params[:id]
  end

  # This is the translator listing page, where clients can invite translators,
  # accept translator applications and so on.
  def language_pair
    begin
      website = Website.where(id: params[:project_id]).first
      # If the user is already authenticated and is authorized to view the
      # website, there is no need to re-authenticate using the accesskey.
      # This fixes iclsupp-1565.
      if website.nil? || @user.nil? || !@user.can_view?(website)
        website = authenticate_project
      end
    rescue AuthorizationError, InvalidParams => e
      logger.info "ERROR #{e} websites#language_pair #{e.message}"
      @message = {
        'header' => 'Not able to authenticate project',
        'additional_desc' => e.message
      }
    end

    #  @ToDo remove this, the most ugly fix ever
    source_language = Language.detect_language(params[:source_language])
    target_language = Language.detect_language(params[:target_language])

    begin
      if source_language.nil? || target_language.nil?
        missing_language = source_language.nil? ? params[:source_language] : params[:target_language]
        #  @ToDO add a language switcher to allow user choose the right language
        raise "The language: \"#{missing_language}\" doesn't exists"
      end

      wto = website.find_or_create_offer(source_language, target_language)
      if wto.nil?
        raise "Can't find the language pair (website translation offer) between #{params[:source_language]} and #{params[:target_language]} in website #{website.id}"
      end
    rescue => error

      logger.info "ERROR websites#language_pair #{error.message}"

      @message = {
        'header' => error.message,
        'additional_desc' => 'Be sure that you are not using a custom language, feel free to contact support if you need help setting up your project.'
      }
    end

    if @message
      render 'shared/error', layout: 'empty'
    else
      redirect_to website_website_translation_offer_url(website, wto, accesskey: params[:accesskey], compact: params[:compact], session: params[:session], lc: params[:lc], disp_mode: params[:disp_mode])
    end
  end

  def translator_chat
    website = authenticate_project
    translator = Translator.find(params[:translator_id])
    wtc = website.website_translation_contracts.find_by(translator_id: translator.id)

    if wtc.blank?
      set_err('This translator is not assigned to this Website Translation project.')
      return
    end

    wto = wtc.website_translation_offer
    redirect_to website_website_translation_offer_website_translation_contract_url(website, wto, wtc)
  end

  def cancel_resignation; end

  def confirm_resignation; end

  def confirmed_resignation
    user = @user.is_translator? ? @user : Translator.find(params[:translator_id])
    @website.resign_from_this_website(user, params[:remarks])
    flash[:notice] = "Successfully resigned from #{@website.name}"
    redirect_to :back
  rescue => e
    flash[:notice] = e.message
    redirect_to :back
  end

  def reveal_wp_credentials
    @err = []
    @err << 'You are forbidden to do this action.' unless @user.has_supporter_privileges?
    @err << 'Invalid password' if @user.get_password != params[:password]
  end

  private

  def locate_website

    @website = Website.find(params[:id].to_i)
    true
  rescue
    set_err('cannot find this website')
    return false

  end

  def setup_user_optional

    accesskey = params[:accesskey]
    if @website && accesskey
      if accesskey == @website.accesskey
        @user = @website.client
        @compact_display = true

        # check if the accesskey_ok status needs to update
        if @website.accesskey_ok != ACCESSKEY_VALIDATED
          @website.update_attributes(accesskey_ok: ACCESSKEY_VALIDATED)
        end
      else
        set_err('cannot access')
        return false
      end
    else
      if setup_user
        if !@user.has_supporter_privileges? && (@website && (@website.client != @user))
          set_err('Not your project')
          return false
        end
      else
        return false
      end
    end

  end

  def verify_client
    unless @user.has_client_privileges? || @user.has_supporter_privileges?
      set_err('You cannot access this page')
      return false
    end
    true
  end

  def verify_admin
    unless @user.has_admin_privileges?
      set_err('You cannot access this page')
      false
    end
  end

  def collect_translation_languages
    # collect the translation language pairs
    idx = 1
    cont = true
    language_pairs = []
    while cont
      lang_name = params["from_language#{idx}"]
      if !lang_name.blank?
        from_lang = Language.find_by(name: lang_name)
        raise "Language doesn't exist: #{lang_name}" unless from_lang
        lang_name = params["to_language#{idx}"]
        raise "Destination language not specified for translation from: #{from_lang.name}" if lang_name.blank?
        to_lang = Language.find_by(name: lang_name)
        raise "Language doesn't exist: #{lang_name}" unless to_lang
        raise "Cannot translate from and to the same language: #{lang_name}" if to_lang == from_lang
        language_pairs << [from_lang, to_lang]
      else
        cont = false
      end
      idx += 1
    end

    language_pairs
  end

  def verify_modify
    unless @user.can_modify?(@website)
      set_err("You can't do that.")
      return false
    end
    true
  end

  def verify_view
    unless @user.can_view?(@website)
      set_err("You can't do that.")
      return false
    end
    true
  end

end
