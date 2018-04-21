class TusController < ApplicationController
  prepend_before_action :setup_user
  before_action :locate_user
  before_action :locate_tu, except: [:index, :search]
  layout :determine_layout

  STATUS_TEXT = { TU_INCOMPLETE => N_('Incomplete'),
                  TU_COMPLETE => N_('Complete') }.freeze

  def index
    @header = _('Translation Memory for %s') % @tu_client.full_name

    @languages = Language.list_major_first

    conds = []
    cond_args = []

    if params[:set_args].blank?
      @original = session[:tu_original]
      @translation = session[:tu_translation]
      @from_language_id = session[:tu_from_language_id]
      @to_language_id = session[:tu_to_language_id]
      @status = session[:tu_status]
    else

      @original = params[:original]
      unless @original.blank?
        conds << '(tus.original LIKE ?)'
        cond_args << '%' + @original + '%'
      end

      @translation = params[:translation]
      unless @translation.blank?
        conds << '(tus.translation LIKE ?)'
        cond_args << '%' + @translation + '%'
      end

      @from_language_id = params[:from_language_id].to_i
      if @from_language_id > 0
        conds << '(tus.from_language_id =  ?)'
        cond_args << @from_language_id
      end

      @to_language_id = params[:to_language_id].to_i
      if @to_language_id > 0
        conds << '(tus.to_language_id =  ?)'
        cond_args << @to_language_id
      end

      @status = (params[:status] || '-1').to_i
      if [TU_COMPLETE, TU_INCOMPLETE].include?(@status)
        conds << '(tus.status =  ?)'
        cond_args << @status
      end

      session[:tu_original] = @original
      session[:tu_translation] = @translation
      session[:tu_from_language_id] = @from_language_id
      session[:tu_to_language_id] = @to_language_id
      session[:tu_status] = @status

    end

    if !conds.empty?
      @filter = true
      conditions = [conds.join(' AND ')] + cond_args
    else
      conditions = nil
    end

    tus = @tu_client.tus.where(conditions)

    @pager = ::Paginator.new(tus.count, PER_PAGE) do |offset, per_page|
      tus.includes(:client).limit(per_page).offset(offset).order('tus.id DESC')
    end

    @tus = @pager.page(params[:page])
    @list_of_pages = []
    for idx in 1..@pager.number_of_pages
      @list_of_pages << idx
    end
  end

  def search
    tu_cnt = params[:tu_cnt].to_i
    if tu_cnt <= 0
      set_err('TU count not specified')
      return
    end

    from_language_id = params[:from_language_id].to_i
    if from_language_id <= 0
      set_err('from language not specified')
      return
    end

    signatures = []
    (1..tu_cnt).each do |idx|
      tu_name = 'sig_%d' % idx
      if params[tu_name].blank?
        set_err('TU %d is not specified' % idx)
        return
      end
      signatures << params[tu_name]
    end

    @tus = {}
    signatures.each do |signature|
      tu = @tu_client.tus.where('(signature=?) AND (from_language_id=?)', signature, from_language_id).first
      @tus[signature] = tu if tu
    end

    respond_to do |format|
      format.html
      format.xml
    end

  end

  private

  def locate_user
    begin
      @tu_client = Client.find(params[:user_id].to_i)
    rescue
      set_err('cannot find user')
      return false
    end

    if (@tu_client != @user) && !@user.has_admin_privileges?
      set_err('Not your TM')
      return false
    end
  end

  def locate_tu
    begin
      @tu = Tu.find(params[:id].to_i)
    rescue
      set_err('cannot find tu')
      return false
    end

    if @tu.client != @tu_client
      set_err('term does not belong to user')
      return false
    end

  end
end
