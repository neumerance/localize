class SearchController < ApplicationController
  prepend_before_action :setup_user
  layout :determine_layout
  before_action :setup_help

  def index
    @header = _('Search projects')
  end

  def projects; end

  def new_projects
    if @user[:type] != 'Translator'
      flash[:notice] = 'Use the advanced search to find projects and other users'
      redirect_to action: :advanced
      return
    end
    # find all project revisions that are open for bidding
    @header = _('Search for new projects')
  end

  def show_new_projects
    @header = _('Search results')
    # construct the SQL quety according to the selected arguments
    min_words = params[:min_words].to_i
    max_words = params[:max_words].to_i
    search_sql = ''
    # if (min_words > 0) || (max_words > 0)
    #	search_sql += " AND (r.word_count >= #{min_words})" if (min_words > 0)
    #	search_sql += " AND (r.word_count <= #{max_words})" if (max_words > 0)
    # end

    @revisions = @user.open_revisions_filtered(!params[:languages].blank?, !params[:categories].blank?, search_sql, "LIMIT #{PER_PAGE}")
  end

  def find
    @header = _('Search results')
    keyword = params[:keyword]
    if !keyword || (keyword == '')
      flash[:notice] = _('No keyword entered')
      render action: :index
      return
    end
    if params[:projects]
      projects = Project.where('name LIKE ?', '%' + keyword + '%')
      @revisions = []
      projects.each do |project|
        @revisions << project.revisions[-1]
      end
      @revisions.delete(nil)
    else
      @revisions = []
    end

    @users = if params[:users]
               User.where('nickname LIKE ?', '%' + keyword + '%')
             else
               []
             end

  end

  def cms_search(user, params)
    @search = params[:search]
    unless @search.nil?
      search_for = params[:search_for]
      search_term = params[:search_term]

      if search_term.nil? || search_term.length < 4
        @error = 'You need to search for at least 4 characters'
        return
      end

      extra_conds = ''
      extra_params = []
      unless user.has_supporter_privileges?
        if user.has_translator_privileges?
          extra_conds += ' AND cms_target_languages.translator_id = ?'
          extra_params << [user.id]
        elsif user.has_client_privileges?
          extra_conds += ' AND websites.client_id = ?'
          extra_params << [user.id]
        end
      end

      if params[:id]
        extra_conds += ' AND websites.id = ?'
        extra_params << params[:id]
      end

      case search_for
      when 'title'
        query = ['cms_requests.title LIKE ?' + extra_conds, "%#{search_term}%"] + extra_params
      when 'original_url'
        query = ['cms_requests.permlink LIKE ?' + extra_conds, "%#{search_term}%"] + extra_params
      when 'translated_url'
        query = ['cms_target_languages.permlink LIKE ?' + extra_conds, "%#{search_term}%"] + extra_params
      else
        @error = 'Invalid search option'
        return
      end

      pager = ::Paginator.new(CmsRequest.joins(:website, :cms_target_language).where(query).count, PER_PAGE) do |offset, per_page|
        CmsRequest.joins(:website, :cms_target_language).where(query).offset(offset).limit(per_page).order('cms_requests.id DESC')
      end
      page = params[:page] || 1
      @cms_requests = pager.page(page)
      @list_of_pages = (1..pager.number_of_pages).to_a
      logger.debug(@list_of_pages)

      return { search: @search, cms_requests: @cms_requests, list_of_pages: @list_of_pages, error: @error }
    end
  end

  def cms
    ret = cms_search(@user, params)
    logger.debug ret.inspect
    if ret.is_a? Hash
      @search = ret[:search]
      @cms_requests = ret[:cms_requests]
      @list_of_pages = ret[:list_of_pages]
      @error = ret[:error]
    end
  end

  def messages; end

  def translators
    @header = _('Translator Search')
    @languages = Language.list_major_first
  end

  def by_language
    @source_lang_id = params[:source_lang_id].to_i
    @target_lang_id = params[:target_lang_id].to_i

    if @user.has_supporter_privileges? && params[:in_behalf_of]
      @user = User.find(params[:in_behalf_of])
    end

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
      @header = _('Translator Search')
      @warning = _('Please select both source and destination languages')
      @languages = Language.list_major_first
      render action: :translators
      return
    end

    @translators = Translator.find_by_languages(USER_STATUS_QUALIFIED, @source_lang_id, @target_lang_id)
    @translators += @user.private_translators.map(&:translator) if @user.respond_to?(:private_translators)
    @translators.uniq!

    @back = request.referer unless params[:go_back].blank?

    @header = _('Translators from %s to %s') % [@source_lang.name, @target_lang.name]

  end

end
