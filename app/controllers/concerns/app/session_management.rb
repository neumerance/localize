module App
  module SessionManagement
    def clear_old_sessions(user_id)
      user_sessions = UserSession.where('(user_id= ?) AND (long_life != ?)', user_id, 1)
      if user_sessions
        if user_sessions.length >= MAX_USER_SESSIONS
          latest = nil
          latest_time = Time.now
          for user_session in user_sessions
            if (user_session.login_time < latest_time) || !latest
              latest = user_session
              latest_time = user_session.login_time
            end
          end
          # delete the oldest user session
          latest.destroy
        end
      end
    end
    private :clear_old_sessions

    def session_was_started_as_admin
      session[:orig_user] && session[:orig_user].has_admin_privileges?
    end

    def create_session_for_user(user, long_life = nil)
      clear_old_sessions(user.id)
      ok = false
      display = COMPACT_SESSION if params[:compact].present?

      until ok
        session_num = Digest::MD5.hexdigest(String(rand))
        begin
          user_session = UserSession.new(user_id: user.id,
                                         session_num: session_num,
                                         login_time: Time.now,
                                         long_life: long_life,
                                         display: display)

          # try to enter to the database, an error will pop-up if the session already exists
          ok = user_session.save!
        rescue
        end
      end
      session[:session_num] = session_num
      user_session
    end

    def get_wid
      wid_s = params[:wid]
      wid_s ||= params[:project_id]
      wid_s ||=
        case params[:controller]
        when 'websites', 'wpml/websites'
          wid_s = params[:id]
        when 'website_translation_offers', 'website_translation_contracts', 'cms_requests'
          wid_s = params[:website_id]
        end
    end
    private :get_wid

    def setup_user(required = true)
      # check if we're logging in to a specific website
      accesskey = params[:accesskey]
      if accesskey
        wid = get_wid
        if wid
          website = Website.find_by(id: wid, accesskey: accesskey)
          if website.nil?
            set_err(_('Cannot locate this website or wrong accesskey'), NOT_LOGGED_IN_ERROR)
            return false
          end

          long_life = !params[:long_life].blank? ? 1 : nil

          @user = website.client
          @user_session = create_session_for_user(@user, long_life)
          @compact_display = (@user_session.display == COMPACT_SESSION)
          session[:session_num] = @user_session.session_num

          # check if there's a return URL to set
          return_url = params[:return_url]
          return_title = params[:return_title]
          if return_url && return_title
            session[:return_to] = [return_url, return_title]
            @return_url = return_url
            @return_title = return_title
          end

          # see if we need to change the user's language
          lc = params[:lc]
          unless lc.blank?
            LOCALES.values.each do |loc_code|
              next unless loc_code.starts_with?(lc.downcase)
              if @user.loc_code != loc_code
                @user.update_attributes(loc_code: loc_code)
              end
              session[:hide_locale_bar] = true
              break
            end
          end

          if @user.loc_code
            if LOCALES.value?(@user.loc_code)
              @locale = @user.loc_code
              @locale_language = Language.where(name: LOCALES.key(@user.loc_code)).first
              set_locale(@locale)
            end
          else
            @locale = DEFAULT_LOCALE
            @locale_language = Language.where(name: LOCALES.key(DEFAULT_LOCALE)).first
            set_locale(DEFAULT_LOCALE)
          end

          return
        end
      end

      if params['session']
        session_num = params['session']
        session[:session_num] = session_num
      else
        session_num = session[:session_num]
      end

      # check if there's a return URL to use
      if session[:return_to]
        @return_url = session[:return_to][0]
        @return_title = session[:return_to][1]
      end

      logger.info("---------- Setting up user from session #{session_num}")

      @user_session = UserSession.where(session_num: session_num).first
      @user = nil
      if @user_session
        # we don't care about session expiration if all the user wants to do is log out
        if @user_session.timed_out && !((params[:controller] == 'login') && (params[:action] == 'logout'))
          @user_session.destroy
          if (params[:controller] != 'login') && !request.xhr?
            session[:go_to_last_url] = true
            set_err(_('Your session has timed out. Please log in again.'), NOT_LOGGED_IN_ERROR)
          elsif params[:format] == 'xml'
            set_err(_('Your session has timed out. Please log in again.'), NOT_LOGGED_IN_ERROR)
          end
          default_locale # this will not reach if the filter chain is broken
          return false
        else
          # if not timed out, refresh the session change time
          # check if the embedded specification exists, if so, save it in the session
          unless params[:embedded].nil?
            @user_session.display = params[:embedded].to_i
          end
          @embedded = (@user_session.display == EMBEDDED_SESSION)
          @compact_display = params[:compact] == '1'
          @user_session.update_chgtime

          @user = @user_session.user

          if @user
            # verify that this user has confirmed his email
            if @user.userstatus == USER_STATUS_NEW
              @user_session.destroy
              redirect_to controller: '/login', action: :complete_registration, id: @user.id
              # check if this locale is OK, if so, use it
            elsif @user[:type] != 'Client'
              set_locale(DEFAULT_LOCALE)
            elsif @user.loc_code
              if LOCALES.value?(@user.loc_code)
                @locale = @user.loc_code
                @locale_language = Language.where(name: LOCALES.key(@user.loc_code)).first
                set_locale(@locale)
                logger.info "------------ 1. set locale to user locale: #{@locale} @locale_language=#{@locale_language ? @locale_language.name : 'blank'} -------------"
              end
            end
          end

          @orig_user = session[:orig_user]

        end
      end

      if @user.nil?
        if required
          if (params[:controller] != 'login') && !request.xhr?
            session[:go_to_last_url] = true
            set_err(_('The page you accessed required logging in. Please log in to your account first.'), NOT_LOGGED_IN_ERROR, request.original_fullpath)
          elsif params[:format] == 'xml'
            set_err(_('The page you accessed required logging in. Please log in to your account first.'), NOT_LOGGED_IN_ERROR)
          else
            redirect_to '/'
          end
          default_locale # this will not reach if the filter chain is broken
          return false
        else

          return true
        end
      else
        # check if this user is going to the wrong place
        if (params[:controller] == 'client') && (@user[:type] == 'Translator')
          redirect_to controller: '/translator'
          return false
        elsif (params[:controller] == 'translator') && (@user[:type] == 'Client')
          redirect_to controller: '/client'
          return false
        else
          @status = 'logged in'
        end
      end

      logger.info("---- User setup OK: ##{@user.id} #{@user.email}, type: #{@user[:type]}. Session ID: #{@user_session.id}")

      # set up site notices
      @active_site_notices = SiteNotice.all_active
      true
    end
  end
end
