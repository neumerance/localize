class TranslatorsController < ApplicationController
  layout 'external'

  def index
    page = (params[:page] || 1).to_i
    @header = if page > 1
                _('Top Professional Translators in ICanLocalize (page %d)') % page
              else
                _('Top Professional Translators in ICanLocalize')
              end

    @meta_description = _('These are some of the top professional translators in ICanLocalize. You can view their profiles and invite them to your translation projects.')

    @pager = ::Paginator.new(Translator.joins(:bionote).where('(userstatus IN (?) AND is_public=?) AND (documents.body IS NOT NULL OR documents.body != "") ', [USER_STATUS_REGISTERED, USER_STATUS_QUALIFIED], 1).count, PER_PAGE) do |offset, per_page|
      Translator.joins(:bionote).where('userstatus IN (?) AND is_public=? AND (documents.body IS NOT NULL OR documents.body != "")', [USER_STATUS_REGISTERED, USER_STATUS_QUALIFIED], 1).includes(:translator_languages, :bionote).limit(per_page).offset(offset).order('users.raw_rating DESC')
    end

    @translators = @pager.page(params[:page])
    @list_of_pages = (1..@pager.number_of_pages).to_a
    @show_number_of_pages = (@pager.number_of_pages > 1)
  end

  def from
    @translators = []
    from_lang = Language.where('name=?', params[:id]).first
    to_lang = Language.where('name=?', params[:to]).first
    @header = _('%s to %s translators') % [params[:id], params[:to]]
    @meta_description = 'Professional %s to %s translators in ICanLocalize.' % [params[:id], params[:to]]
    unless from_lang.blank? || to_lang.blank?
      @translators = Translator.find_by_languages(USER_STATUS_QUALIFIED, from_lang.id, to_lang.id, ' AND (is_public=1) ')
    end
  end

  def show
    begin
      @translator = Translator.find(params[:id].to_i)
    rescue ActiveRecord::RecordNotFound => e
      render_html_error e
      return false
    end
    redirect_to '/' unless @translator.is_public?

    if (@translator.to_languages.length >= 1) && !@translator.country.blank?
      @meta_description = _('%s, native %s translator from %s.') % [@translator.nickname, (!@translator.to_languages.empty? ? @translator.to_languages.first.nname : nil), @translator.country.nname]
    end

    @header = @translator.full_name + (!@translator.country.blank? ? ', %s' % @translator.country.nname : '')
    @is_single = true

    @back = request.referer
  end

  def compare
    @translators = []
    idx = 1
    cont = true
    while cont
      if !params['check_translator_%d' % idx].blank?
        t_id = params['check_translator_%d' % idx].to_i
        unless params['translator_%d' % t_id].blank?
          begin
            translator = Translator.find(t_id)
            @translators << translator
          rescue
          end
        end
        idx += 1
      else
        cont = false
      end
    end
    @div = params[:div]
  end

  def hide_compare
    @div = params[:div]
    logger.info "---------- going to replace #{@div}"
  end
end
