class WebsiteTranslationOffersController < ApplicationController
  include ::AuthenticateProject
  include ::ValidateCmsAccess

  prepend_before_action :locate_website, except: [:create]
  prepend_before_action :setup_user, except: [:create]

  before_action :locate_offer, only: [:show, :resend_notifications, :edit_description, :update, :destroy, :new_invitation, :create_invitation, :add_count, :enter_details, :update_details, :update_site_status, :report, :review, :auto_setup, :resign_from_website]
  before_action :forbid_for_autoassign_language_pairs, except: [:index, :review, :report, :resign_from_website], unless: -> { request.format.json? }
  before_action :verify_client, except: [:review, :resign_from_website, :report, :create]

  before_action :setup_help
  layout :determine_layout
  before_action :verify_view, only: %w(show auto_setup)
  before_action :verify_modify, only: %w(create_invitation)

  def index
    @header = _('Translation offers for %s') % @website.name
    @website_translation_offers = @website.website_translation_offers
  end

  def new
    redirect_to action: :index
    nil
  end

  def open_applications
    website_translation_contracts.where('website_translation_contracts.status NOT IN (?)', [TRANSLATION_CONTRACT_ACCEPTED, TRANSLATION_CONTRACT_DECLINED])
  end

  def cancel_invitations
    website_translation_offer = WebsiteTranslationOffer.find(params[:id])
    website_translation_offer.update_attribute :status, TRANSLATION_OFFER_CLOSED

    # Keep track to get statistics
    from_language = website_translation_offer.from_language
    to_language = website_translation_offer.to_language
    campaing_track = CampaingTrack.
                     where(
                       "campaing_id = ? and
                       from_language_id = ? and to_language_id = ? and
                       project_type = ? and project_id = ?",
                       2,
                       from_language.id,
                       to_language.id,
                       'Website',
                       website_translation_offer.website_id
                     ).first

    if campaing_track
      campaing_track.state = 2
      campaing_track.save
    end

    flash[:notice] = 'We will not send the notification to the translators. You can verify their profiles bellow and invite the ones you like most and invite manually.'
    redirect_to [@website, website_translation_offer]
  end

  def create
    head :not_acceptable unless request.format == Mime[:json]
    website = authenticate_project

    enforce_hash_with_params('language pair', params, [:source_language, :target_language])
    source_language = Language.find_by(name: params[:source_language])
    raise Language::NotFound, params[:source_language] unless source_language
    target_language = Language.find_by(name: params[:target_language])
    raise Language::NotFound, params[:target_language] unless target_language

    # When WPML (TP) sends CmsRequests to ICL, the new WPML flow requires
    # WebsiteTranslationOffers to be created immediately. So they should already
    # exist at this point.
    wto = WebsiteTranslationOffer.find_or_create_by!(
      from_language: source_language,
      to_language: target_language,
      website: website
    )

    # When automatic translator assignment is enabled, the language pair should
    # not be visible for translators to apply.
    status = wto.automatic_translator_assignment? ? TRANSLATION_OFFER_CLOSED : TRANSLATION_OFFER_OPEN

    wto.update!(
      url: website.url,
      status: status,
      notified: 0
    )

    respond_to do |format|
      format.json
    end
  end

  def load_or_create_from_ta
    enforce_hash_with_params('wto language pair', params, [:wid, :from_language_id, :to_language_id, :words, :deadline])

    params[:project_id] = params[:wid]
    website = authenticate_project

    source_language = Language.find params[:from_language_id]
    raise Language::NotFound, params[:from_language_id] unless source_language
    target_language = Language.find params[:to_language_id]
    raise Language::NotFound, params[:to_language_id] unless target_language

    wto = WebsiteTranslationOffer.find_by(website_id: website.id, from_language_id: source_language.id, to_language_id: target_language.id)
    if wto.nil?
      wto = website.website_translation_offers.create(
        from_language_id: params[:from_language_id],
        to_language_id: params[:to_language_id],
        url: website.url,
        status: TRANSLATION_OFFER_OPEN,
        notified: 0
      )
      raise WebsiteTranslationOffer::NotCreated, wto if wto.new_record?
    end

    redirect_to auto_setup_website_website_translation_offer_url(website.id, wto.id, wid: website.id, accesskey: website.accesskey, auto_setup: true, words: params[:words], deadline: params[:deadline])
  end

  def auto_setup
    @website_translation_offer.auto_configure(params[:deadline], params[:words])
    @language = @website_translation_offer.to_language
    @deadline = params[:deadline].to_date.strftime('%Y %b, %d')
    @words = params[:words]
    @website_translation_offer.allow_translators_to_apply!
    @translators = Translator.find_by_languages(USER_STATUS_QUALIFIED, @website_translation_offer.from_language_id, @website_translation_offer.to_language_id)

    # Keep track to get statistics
    from_language = @website_translation_offer.from_language
    to_language = @website_translation_offer.to_language
    campaing_track = CampaingTrack.
                     where(
                       "campaing_id = ? and
                       from_language_id = ? and to_language_id = ? and
                       project_type = ? and project_id = ?",
                       2,
                       from_language.id,
                       to_language.id,
                       'Website',
                       @website_translation_offer.website_id
                     ).first

    if campaing_track
      campaing_track.state = 1 if campaing_track.state == 0
      campaing_track.save
    end

    render layout: false
  end

  def show
    redirect_to wpml_website_translation_jobs_path(@website_translation_offer.website) if @user.is_client? && @website_translation_offer.automatic_translator_assignment
    @disp_mode = params[:disp_mode].present? ? params[:disp_mode].to_i : DISPLAY_ALL_TRANSLATORS
    @campaing_id = params[:c]
    if (@disp_mode == DISPLAY_TRANSLATORS_IN_CATEGORY) && @website.category && !Translator.find_by_languages(USER_STATUS_QUALIFIED, @website_translation_offer.from_language_id, @website_translation_offer.to_language_id, "AND (translator_categories.category_id=#{@website.category_id})").empty?
      unsorted_translators = Translator.find_by_languages(USER_STATUS_QUALIFIED, @website_translation_offer.from_language_id, @website_translation_offer.to_language_id, "AND (translator_categories.category_id=#{@website.category_id})")
    elsif @disp_mode == DISPLAY_INVITED_TRANSLATORS
      contracts = @website_translation_offer.website_translation_contracts.where('invited=1').includes(:translator)
      unsorted_translators = contracts.collect(&:translator)
    elsif @disp_mode == DISPLAY_ACCEPTED_TRANSLATORS
      contracts = @website_translation_offer.website_translation_contracts.where('website_translation_contracts.status=?', TRANSLATION_CONTRACT_ACCEPTED).includes(:translator)
      unsorted_translators = contracts.collect(&:translator)
    elsif @disp_mode == DISPLAY_APPLIED_TRANSLATORS
      contracts = @website_translation_offer.website_translation_contracts.includes(:translator)
      unsorted_translators = contracts.collect(&:translator)
    else # @disp_mode == DISPLAY_ALL_TRANSLATORS
      unsorted_translators = Translator.find_by_languages(USER_STATUS_QUALIFIED, @website_translation_offer.from_language_id, @website_translation_offer.to_language_id)
    end

    @translators = []
    gr1 = [] # both bio and feedback
    gr2 = [] # only bio
    gr3 = [] # others
    unsorted_translators.each do |translator|
      markings = translator.markings.where('bookmarks.note != ?', '').length
      bionote = translator.bionote ? translator.bionote.i18n_txt(@locale_language) : nil
      if !bionote.blank? && (markings > 0)
        gr1 << translator
      elsif !bionote.blank?
        gr2 << translator
      else
        gr3 << translator
      end
    end

    if [DISPLAY_ALL_TRANSLATORS, DISPLAY_TRANSLATORS_IN_CATEGORY].include? @disp_mode
      @translators += @website.client.private_translators.map(&:translator)
    end

    @translators += gr1 + gr2 + gr3
    @translators += @website_translation_offer.accepted_website_translation_contracts.map(&:translator)
    @translators.uniq!
    @translators.reject!(&:nil?)

    # create a cache of contracts per translator
    @translator_contracts = {}
    contracts = @website_translation_offer.website_translation_contracts.where(status: TRANSLATION_CONTRACT_ACCEPTED)
    @minimum_bid_amount = contracts.minimum(:amount)
    @maximum_bid_amount = contracts.maximum(:amount)
    @website_translation_offer.website_translation_contracts.each do |contract|
      @translator_contracts[contract.translator] = contract
    end

    @header = _('%s to %s translators') % [@website_translation_offer.from_language.nname, @website_translation_offer.to_language.nname]
    @offer_status = WebsiteTranslationOffer::STATUS_TEXT.keys.sort.collect { |os| [WebsiteTranslationOffer::STATUS_TEXT[os], os] }

    # if @website_translation_offer.invitation.blank? && !@website.wc_description.blank?
    # @website_translation_offer.invitation = @website.wc_description
    # end

    @create_account = true
    @title = @website.name
    @description = @website.description
    @categories = Category.list
  end

  def report
    @header = _('Project statistics for %s to %s') % [@website_translation_offer.from_language.nname, @website_translation_offer.to_language.nname]
    @completed = { STATISTICS_WORDS => { false => 0, true => 0 }, STATISTICS_DOCUMENTS => { false => 0, true => 0 } }
    @website.cms_target_languages.joins(:cms_request).
      where('(cms_requests.language_id=?) AND (cms_target_languages.language_id=?)', @website_translation_offer.from_language.id, @website_translation_offer.to_language.id).each do |cms_target_language|

      next if cms_target_language.word_count.nil?
      if [CMS_REQUEST_TRANSLATED, CMS_REQUEST_DONE].include?(cms_target_language.cms_request.status)
        @completed[STATISTICS_DOCUMENTS][true] += 1
        @completed[STATISTICS_WORDS][true] += cms_target_language.word_count
      else
        @completed[STATISTICS_DOCUMENTS][false] += 1
        @completed[STATISTICS_WORDS][false] += cms_target_language.word_count
      end
    end

    @back = request.referer
  end

  def update
    @website_translation_offer.update_attributes(params[:website_translation_offer])
    flash[:notice] = _('Translation offer updated')
    redirect_to action: :show
  end

  def edit_description
    # not supported any more
    # req = params[:req]
    # if req == 'show'
    #   @editing = true
    # elsif req.nil?
    #   @warning = validate_cms_access(params[:website_translation_offer], @website.platform_kind, false, @website.pickup_type, @website)
    #   if @warning.nil?
    #     @website_translation_offer.update_attributes!(params[:website_translation_offer])
    #   end
    # end
  end

  def destroy
    @website_translation_offer.destroy
    flash[:notice] = _('Translation language deleted')
    redirect_to controller: '/wpml/websites', action: :show, id: @website.id
  end

  def resend_notifications
    @website_translation_offer.sent_notifications.each(&:destroy)
    flash[:notice] = _('We will send notifications again soon.')
    redirect_to controller: '/wpml/websites', action: :show, id: @website.id
  end

  def enter_details
    @header = _('Get Applications from Translators')
    @create_account = true

    @title = @website.name
    @description = @website.description
    @categories = Category.list
  end

  def update_details
    # check if we need the user and website arguments
    ok = false

    @title = params[:title]
    @description = params[:description]
    @website_translation_offer.sample_text = params[:website_translation_offer][:sample_text] if params[:website_translation_offer]

    @create_account = (params[:create_account].to_i == 1)
    @fname = params[:fname]
    @lname = params[:lname]
    @email = params[:email]
    @email1 = params[:email1]
    @password = params[:password]
    @category_id = params[:category_id].to_i
    @voucher = params[:voucher]

    invitation_only = (params[:invitation_only].to_i == 1)
    offer_status = invitation_only ? TRANSLATION_OFFER_CLOSED : TRANSLATION_OFFER_OPEN

    # invitation_only means translators that were not invited cannot apply
    unless invitation_only
      if @title.blank?
        @website_translation_offer.errors.add(:base, _('Title cannot be blank'))
      end

      if @description.blank?
        @website_translation_offer.errors.add(:base, _('Description cannot be blank'))
      end

      begin
        category = Category.find(@category_id)
      rescue
        category = nil
      end
      @website.category = category
    end

    # Anonymous users are used by older versions of WPML, which did not require
    # the user to register for a ICL account in order to use it.
    if (@user.anon == 1) && !invitation_only
      if @create_account
        if @fname.blank?
          @website_translation_offer.errors.add(:base, _('First name cannot be blank'))
        end
        if @lname.blank?
          @website_translation_offer.errors.add(:base, _('Last name cannot be blank'))
        end
        if @email.blank?
          @website_translation_offer.errors.add(:base, _('Email name cannot be blank'))
        elsif User.where('email=?', @email).first
          @website_translation_offer.errors.add(:base, _('Email already exists in our system, use a different one'))
        end
        if @voucher && @voucher.present?
          voucher = Voucher.find_by code: @voucher
          unless voucher
            @website_translation_offer.errors.add(:base, _('Voucher code is not valid'))
          end
        end
      else
        existing_user = Client.where('email=?', @email1).first
        if !existing_user || (existing_user.get_password != @password)
          @website_translation_offer.errors.add(:base, _('Wrong email or password'))
        end
      end
    end

    if @website_translation_offer.errors.count == 0
      # check if we need to update the user information
      if (@user.anon == 1) && !invitation_only
        if @create_account
          # update the user
          base_nickname = @fname + '.' + @lname[0..0]
          nickname_cnt = User.where('nickname LIKE ?', base_nickname + '%').count
          idx = nickname_cnt + 1
          while User.where('nickname = ?', (base_nickname + idx.to_s)).first
            idx += 1
          end
          nickname = base_nickname + idx.to_s
          password = Digest::MD5.hexdigest(Time.now.to_s)[0...8].tr('0', '9').tr('1', '3')

          userstatus = USER_STATUS_REGISTERED

          ok = @user.update_attributes(fname: @fname, lname: @lname, email: @email, nickname: nickname,
                                       password: password, userstatus: userstatus, anon: 0)

          if voucher
            begin
              voucher.activate_on_user(@user)
            rescue => e
              logger.error ' --- NOT ABLE TO ACTIVATE VOUCHER ----'
              logger.error e.message
              logger.error e.backtrace
            end
          end

          if ok && @user.can_receive_emails?
            ReminderMailer.welcome_cms_user(@user, 'Translation Management').deliver_now
          end
        else
          @website.client = existing_user
          ok = @website.save
          @website.reload

          @user.reload
          # TODO: investigate why the user is destroyed here
          @user.destroy
          @user = existing_user
          @user.reload

          @user_session = create_session_for_user(@user)
        end
      else
        ok = true
      end

      if ok
        if params[:reuse_translators]
          redirect_to_url = url_for(controller: '/wpml/websites', action: 'show', id: @website.id) + '#reuse_translators'
        else # Invite all translators
          invite_translators_count = @website_translation_offer.invite_all_translators!
          if invite_translators_count > 0
            ok = true
            @website_translation_offer.update!(invited_all_translators: true, status: offer_status)
            flash[:notice] = 'All translators were invited. You should start receiving responses shortly.'
          end
          @website.update_attributes(name: @title, description: @description, category_id: @category_id, anon: 0)
        end
      end
    end

    @ok = ok
    @redirect_to_url = redirect_to_url
    @invitation_only = invitation_only
    @categories = Category.list

    respond_to do |format|
      format.html { redirect_to website_website_translation_offer_path(@website, @website_translation_offer) }
      format.js # Render the .js.erb template implicitly
    end
  end

  def new_invitation
    @translator = Translator.find(params[:translator_id].to_i)
    @header = _('Invite %s') % @translator.full_name
    @create_account = true

    @title = @website.name
    @description = @website.description
    @categories = Category.list

    @back = request.referer
  end

  def create_invitation
    @back = params[:back]
    @translator = Translator.find(params[:translator_id].to_i)

    # check if we need the user and website arguments
    ok = false

    @website_translation_offer.sample_text = params[:website_translation_offer][:sample_text] if params[:website_translation_offer]

    @category_id = params[:category_id].to_i
    begin
      category = Category.find(@category_id)
    rescue
      category = nil
    end
    @website.category = category

    if @website.anon == 1
      @title = params[:title]
      @description = params[:description]

      @create_account = (params[:create_account].to_i == 1)
      @fname = params[:fname]
      @lname = params[:lname]
      @email = params[:email]
      @email1 = params[:email1]
      @password = params[:password]

      if @title.blank?
        @website_translation_offer.errors.add(:base, 'Title cannot be blank')
      end
      if @description.blank?
        @website_translation_offer.errors.add(:base, 'Description cannot be blank')
      end

      if @user.anon == 1
        if @create_account
          if @fname.blank?
            @website_translation_offer.errors.add(:base, 'First name cannot be blank')
          end
          if @lname.blank?
            @website_translation_offer.errors.add(:base, 'Last name cannot be blank')
          end
          if @email.blank?
            @website_translation_offer.errors.add(:base, 'Email name cannot be blank')
          elsif User.where('email=?', @email).first
            @website_translation_offer.errors.add(:base, 'Email already exists in our system, use a different one')
          end
        else
          existing_user = Client.where('email=?', @email1).first
          if !existing_user || (existing_user.get_password != @password)
            @website_translation_offer.errors.add(:base, 'Wrong email or password')
          end
        end
      end

      if @website_translation_offer.errors.count == 0

        # check if we need to update the user information
        if @user.anon == 1
          if @create_account
            # update the user
            base_nickname = @fname + '.' + @lname[0..0]
            nickname_cnt = User.where('nickname LIKE ?', base_nickname + '%').count
            idx = nickname_cnt + 1
            while User.where('nickname = ?', (base_nickname + idx.to_s)).first
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
            @website.client = existing_user
            ok = @website.save
            @website.reload

            @user.reload
            @user.destroy
            @user = existing_user
            @user.reload

            @user_session = create_session_for_user(@user)
          end
        else
          ok = true
        end

        if ok
          @website_translation_offer.save
          @website.assign_attributes(name: @title, description: @description, anon: 0, category_id: (category ? category.id : nil))
          if @website.valid?
            @website.save
          else
            flash[:notice] = @website.errors.full_messages.join('<br />')
          end
        end

      end
    else
      if @website_translation_offer.errors.count == 0
        @website.save
        @website_translation_offer.save
        ok = true
      end
    end

    if ok
      @website_translation_offer.reload
      @website.reload

      website_translation_contract = @website_translation_offer.invite_translator(@translator)

      if website_translation_contract
        flash[:notice] = _('You have invited %s') % @translator.full_name
        redirect_to(
          controller: :website_translation_contracts,
          action: :show,
          website_id: @website.id,
          website_translation_offer_id: @website_translation_offer.id,
          id: website_translation_contract.id
        )
      end

    else
      @categories = Category.list
      render(action: :new_invitation)
    end

  end

  def update_site_status
    status = params[:status].to_i
    @website.update_attributes(project_kind: status)

    @create_account = true
    @title = @website.name
    @description = @website.description
    @categories = Category.list
  end

  def review
    @header = '%s to %s review for %s' % [@website_translation_offer.from_language.name, @website_translation_offer.to_language.name, @website.name]
  end

  def resign_from_website
    @translator = @user.is_translator? ? @user : Translator.find(params[:translator_id])
    @header = 'Resign from %s' % @website.name
  end

  private

  def locate_website
    @website = Website.find(params[:website_id].to_i)
  rescue
    set_err('Cannot locate website')
    return false
  end

  def locate_offer
    begin
      @website_translation_offer = WebsiteTranslationOffer.find(params[:id].to_i)
    rescue
      set_err('Cannot locate offer')
      return false
    end
    if @website_translation_offer.website != @website
      set_err("Offer doesn't belong to website")
      return false
    end

  end

  def verify_client
    unless @user.has_client_privileges?
      set_err('Not your project')
      false
    end
  end

  def verify_view
    unless @user.can_view?(@website)
      set_err("You can't do that.")
      false
    end
  end

  def verify_modify
    unless @user.can_modify?(@website)
      set_err("You can't do that.")
      false
    end
  end

  # Language pairs with automatic translator assignment enable should not allow
  # anyone to use most of the actions of this page, as we don't want translators
  # applying to those language pairs, nor clients or supporters inviting
  # translators. This callback is only called for non-JSON requests.
  def forbid_for_autoassign_language_pairs
    fallback_path = @user.is_a?(Translator) ? '/translator' : wpml_website_path(@website)

    if @website_translation_offer.automatic_translator_assignment
      redirect_back(fallback_location: fallback_path,
                    notice: 'You cannot access this page because the language ' \
                            'pair has automatic translator assignment enabled.')
      return false
    end
  end
end
