module App
  module Locale
    def default_locale
      # controllers may set this global flag to prevent the locale setting per user
      @locale = params[:loc_code] if params[:loc_code]
      if !@locale && params[:lc]
        @locale = LOCALES.values.find do |v|
          v.starts_with?(params[:lc].downcase)
        end
        # @user = setup_user(false)
      end

      # From session
      @locale = session[:loc_code] if session[:loc_code] && @locale.nil?

      # From previous page
      if !@locale && request.referer && !session[:ignore_referer]
        user_language = nil
        if request.referer.index('/site/de/')
          user_language = 'German'
        elsif request.referer.index('/site/fr/')
          user_language = 'French'
        elsif request.referer.index('/site/es/')
          user_language = 'Spanish'
        elsif request.referer.index('/site/it/')
          user_language = 'Italian'
        elsif request.referer.index('/site/ja/')
          user_language = 'Japanese'
        elsif request.referer.index('/site/')
          user_language = 'English'
        end

        if user_language && LOCALES.key?(user_language)
          @locale = LOCALES[user_language]
        end
      end

      # Default locale
      @locale = DEFAULT_LOCALE if !@locale || !LOCALES.value?(@locale)
      # TODO: fix infinite loop. spetrunin 10/26/16
      # set_locale @locale
      session[:loc_code] = @locale # make sure this continues for the session

      session[:ignore_referer] = nil unless request.xhr?

      # keep the history of visited locations
      clear_history_now = (params[:controller] == 'login') && (params[:action] == 'logout')
      history = session[:last_url]
      if history.nil? || clear_history_now
        history = []
      elsif history.class != Array
        history = []
      end
      # check if this is an AJAX call. If so, ignore it
      if !request.xhr? && !clear_history_now && (params[:controller] != 'login') && (params[:controller] != 'admin') && (params[:format] != 'xml')
        history << request.fullpath
        history = history[1, 5] if history.length > 5
      end
      session[:last_url] = history
    end

    def set_locale_for_lang(language)
      if LOCALES.key?(language.name)
        set_locale(LOCALES[language.name])
        logger.info "------------- set locale to: #{LOCALES[language.name]}"
      end
    end

    def update_locale(locale)
      # if a user is logged in, save in his profile
      # in any case, update the session (good for non-logged in users)
      if LOCALES.value?(locale)
        if @user
          @user.loc_code = locale
          @user.save!
        end
        session[:loc_code] = locale
      end
    end

    def set_user_locale(user)
      @prev_locale = @locale
      if LOCALES.value?(user.loc_code)
        set_locale(user.loc_code)
      else
        set_locale(DEFAULT_LOCALE)
      end
    end

    def restore_locale
      set_locale(@prev_locale)
    end
  end
end
