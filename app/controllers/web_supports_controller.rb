# This is deprecated and obsolete
require 'rexml/document'

class WebSupportsController < ApplicationController
  prepend_before_action :setup_user
  before_action :locate_web_support, only: [:show, :edit, :update, :delete, :customize, :new_department, :create_department, :edit_department, :update_department, :delete_department, :integration_details, :departments, :browse_tickets, :browse_department_tickets, :add_branding, :edit_branding, :del_branding, :confirm_delete_dialogs, :delete_dialogs]
  before_action :locate_department, only: [:edit_department, :update_department, :delete_department, :show_department, :browse_department_tickets]
  before_action :setup_help
  layout :determine_layout

  def index
    @web_supports = @user.web_supports
    @header = _('Your support centers')
  end

  def untranslated_messages
    @account = @user.money_accounts.where('currency_id=?', DEFAULT_CURRENCY_ID).first
    @required_deposit = 0
    if @account
      @required_deposit = WebMessage.missing_funding_for_user(@user).ceil_money
    end

    @current_balance	= @account.balance
    @pending_translation	= @user.web_messages_pending_translation('')
    @pending_review	= @user.web_messages_pending_review('')
    @translation_costs	= @pending_translation.inject(0) { |mem, v| mem += v.translation_price }
    @review_costs	= @pending_review.inject(0) { |mem, v| mem += v.review_price }

    if @required_deposit == 0
      @header = _('No deposit needed')
      @detailed_message = ''
    else
      @header = _('Funding needed for Instant Translation projects and customer support messages')
      @detailed_message = _('There are Instant Translation projects or customer support messages that require funding in order to be translated.')
    end

  end

  def new
    @web_support = WebSupport.new
    @header = _('Create a new support center')
  end

  def create
    @web_support = WebSupport.new(params[:web_support])
    @web_support.client = @user
    if @web_support.save
      redirect_to action: :show, id: @web_support.id
    else
      @header = _('Create a new support center')
      render action: :new
    end
  end

  def show
    @header = _('Settings for %s') % @web_support.name
    @web_dialogs = @web_support.pending_web_dialogs.order('web_dialogs.id DESC').limit(PER_PAGE)
    pending_web_dialogs_count = @web_support.pending_web_dialogs.count
    @web_dialogs_message = if @web_dialogs.length > pending_web_dialogs_count
                             _('This list shows the last %d pending support tickets out of all %d pending tickets') % [@web_dialogs.length, pending_web_dialogs_count]
                           else
                             _('You have %d pending support tickets (all shown below)') % @web_dialogs.length
                           end
  end

  def edit
    @header = _('Rename %s') % @web_support.name
  end

  def delete
    @web_support.destroy
    flash[:notice] = _('Support center deleted')
    redirect_to action: 'index'
  end

  def customize
    @header = _('Customize %s') % @web_support.name
    @brandings = @web_support.brandings
    @brandings = [Branding.new] if @brandings.empty?
    existing_language_ids = []
    @brandings.each { |branding| existing_language_ids << branding.language_id unless branding.language_id.nil? }
    @available_branding_languages = Language.list_major_first(existing_language_ids)
  end

  def update
    if @web_support.update_attributes(params[:web_support])
      redirect_to action: :index
    else
      @header = _('Edit and customize %s') % @web_support.name
      render action: :edit
    end
  end

  def integration_details
    @header = _('Web integration information for %s') % @web_support.name
    @key = Digest::MD5.hexdigest(@user.id.to_s + CAPTCHA_RAND)
    @languages = Language.list_major_first

    lang_id = params[:source_language_id].to_i
    lang_id = 1 if lang_id == 0
    begin
      source_language = Language.find(lang_id)
    rescue
      source_language = Language.find(1)
    end
    @source_language_id = source_language.id

    @preview_heading = _('Your contact page in %s') % source_language.name

    @client_department = @web_support.client_departments.where('id=?', params[:client_department_id].to_i).first
    if @client_department
      @client_department_id = @client_department.id
      logger.info "+++++++++ found @client_department: #{@client_department.id}"
    end

    set_locale_for_lang(source_language)

    @contact_us_text = _('Contact us')

    @html_style_id = params[:html_style].to_i
    @html_style = [['HTML 4.01', 0], ['XHTML 1', 1]]

    xml = REXML::Document.new
    form = REXML::Element.new('form', xml)
    form.add_attributes('action' => url_for(controller: :web_dialogs, action: 'create', only_path: false),
                        'method' => 'POST')
    table = REXML::Element.new('table', form)
    table.add_attributes('border' => '0', 'cellpadding' => '3')

    if !@client_department && (@web_support.client_departments.length > 1)
      tr = REXML::Element.new('tr', table)
      td = REXML::Element.new('td', tr)
      td.add_attributes('valign' => 'top')
      td.text = _('Department') + ':'
      td = REXML::Element.new('td', tr)
      @web_support.client_departments.each do |client_department|
        label = REXML::Element.new('label', td)
        inp = REXML::Element.new('input', label)
        inp.add_attributes('id' => "web_dialog_client_department_id_#{client_department.id}", 'name' => 'web_dialog[client_department_id]', 'type' => 'radio', 'value' => client_department.id.to_s)
        label.text = client_department.name.gsub(' ', '&nbsp;')
        br = REXML::Element.new('br', td)
      end
    end

    [['fname', _('First name')], ['lname', _('Last name')], ['email', _('E-Mail')]].each do |field|
      tr = REXML::Element.new('tr', table)
      td = REXML::Element.new('td', tr)
      td.text = field[1] + ':'
      td = REXML::Element.new('td', tr)
      inp = REXML::Element.new('input', td)
      inp.add_attributes('id' => "web_dialog_#{field[0]}", 'name' => "web_dialog[#{field[0]}]", 'size' => '30', 'type' => 'text')
    end

    tr = REXML::Element.new('tr', table)
    td = REXML::Element.new('td', tr)
    td.add_attributes('colspan' => '2')
    hr = REXML::Element.new('hr', td)

    tr = REXML::Element.new('tr', table)
    td = REXML::Element.new('td', tr)
    td.text = _('Subject') + ':'
    td = REXML::Element.new('td', tr)
    inp = REXML::Element.new('input', td)
    inp.add_attributes('id' => 'web_dialog_visitor_subject', 'name' => 'web_dialog[visitor_subject]', 'size' => '40', 'type' => 'text')

    tr = REXML::Element.new('tr', table)
    td = REXML::Element.new('td', tr)
    td.add_attributes('valign' => 'top')
    td.text = _('Message') + ':'
    td = REXML::Element.new('td', tr)
    inp = REXML::Element.new('textarea', td)
    inp.add_attributes('id' => 'web_dialog_message', 'name' => 'web_dialog[message]', 'rows' => '8', 'cols' => '40')
    inp.text = ' '

    tr = REXML::Element.new('tr', table)
    td = REXML::Element.new('td', tr)
    td.add_attributes('colspan' => '2')
    hr = REXML::Element.new('hr', td)

    tr = REXML::Element.new('tr', table)
    td = REXML::Element.new('td', tr)
    td.add_attributes('colspan' => '2')
    td.text = _('To avoid spam we ask you to repeat the code you see in the image.')

    tr = REXML::Element.new('tr', table)
    td = REXML::Element.new('td', tr)
    td.text = _('Verification code') + ':'
    td = REXML::Element.new('td', tr)
    img = REXML::Element.new('img', td)
    img.add_attributes('name' => 'CaptchaImage', 'id' => 'CaptchaImage', 'src' => '', 'width' => '150', 'height' => '40', 'alt' => 'Verification')

    tr = REXML::Element.new('tr', table)
    td = REXML::Element.new('td', tr)
    td.text = _('Enter code') + ':'
    td = REXML::Element.new('td', tr)
    inp = REXML::Element.new('input', td)
    inp.add_attributes('id' => 'code', 'name' => 'code', 'size' => '8', 'type' => 'text')

    tr = REXML::Element.new('tr', table)
    td = REXML::Element.new('td', tr)
    td.add_attributes('colspan' => '2')
    inp = REXML::Element.new('input', td)
    inp.add_attributes('name' => 'commit',
                       'type' => 'submit',
                       'value' => _('Send message'),
                       'onclick' => "this.setAttribute('originalValue', this.value);this.disabled=true;this.value='%s';;result = (this.form.onsubmit ? (this.form.onsubmit() ? this.form.submit() : false) : this.form.submit());if (result == false) { this.value = this.getAttribute('originalValue'); this.disabled = false };return result" % _('Send message'))
    # <input name="commit" onclick="this.setAttribute('originalValue', this.value);this.disabled=true;this.value='Processing...';;result = (this.form.onsubmit ? (this.form.onsubmit() ? this.form.submit() : false) : this.form.submit());if (result == false) { this.value = this.getAttribute('originalValue'); this.disabled = false };return result" type="submit" value="Send message" />

    inp = REXML::Element.new('input', form)
    inp.add_attributes('id' => 'store', 'name' => 'store', 'type' => 'hidden', 'value' => String(@web_support.id))

    inp = REXML::Element.new('input', form)
    inp.add_attributes('id' => 'rand', 'name' => 'rand', 'type' => 'hidden', 'value' => '')

    inp = REXML::Element.new('input', form)
    inp.add_attributes('id' => 'web_dialog_visitor_language_id', 'name' => 'web_dialog[visitor_language_id]', 'type' => 'hidden', 'value' => String(source_language.id))

    if @client_department
      inp = REXML::Element.new('input', form)
      inp.add_attributes('id' => 'web_dialog_client_department_id', 'name' => 'web_dialog[client_department_id]', 'type' => 'hidden', 'value' => String(@client_department.id))
    elsif @web_support.client_departments.length == 1
      inp = REXML::Element.new('input', form)
      inp.add_attributes('id' => 'web_dialog_client_department_id', 'name' => 'web_dialog[client_department_id]', 'type' => 'hidden', 'value' => String(@web_support.client_departments[0].id))
    end

    js = '<script src="http://www.icanlocalize.com/javascripts/loadcaptcha.js" type="text/javascript"></script>' + "\n"
    js += '<script type="text/javascript" language="JavaScript">LoadCaptcha(' + @user.id.to_s + ',"' + @key + '");</script>'

    @user_html = ''

    xml.write(@user_html, 0) # 2
    @user_html += "\n\n" + js

    @user_html = @user_html.gsub('/>', '>') if @html_style_id != 1

    @user_html = @user_html.gsub('<', '&lt;').gsub('>', '&gt;').gsub('"', '&quot;').gsub("'", '&quot;').gsub(' </textarea>', '</textarea>').gsub(/&gt;[ \t\r\n]*&lt;/, '&gt;&lt;').gsub(/[ \t\r\n]*&lt;/, '&lt;').gsub(/&gt;[ \t\r\n]*/, '&gt;')
    set_locale @locale

  end

  def departments
    @header = _('Departments for %s') % @web_support.name
  end

  def browse_tickets
    @header = _('All tickets for %s') % @web_support.name

    # set up the search conditions
    @ticket_conditions = {}

    if !params[:set_args].blank?
      @ticket_conditions['fname'] = params[:fname] unless params[:fname].blank?
      @ticket_conditions['lname'] = params[:lname] unless params[:lname].blank?
      @ticket_conditions['email'] = params[:email] unless params[:email].blank?

      @ticket_conditions['subject'] = params[:subject] unless params[:subject].blank?
      @ticket_conditions['only_pending'] = params[:only_pending]

      if !params[:client_department_id].blank? && (params[:client_department_id].to_i != 0)
        client_department = @web_support.client_departments.where('id=?', params[:client_department_id].to_i).first
        if client_department
          @ticket_conditions['client_department_id'] = client_department.id
          @header = _("All tickets for %s's %s") % [@web_support.name, client_department.name]
        end
      end

      session[:ticket_conditions] = @ticket_conditions
    elsif session[:ticket_conditions]
      @ticket_conditions = session[:ticket_conditions]
    end

    cond_str = nil
    unless @ticket_conditions.keys.empty?
      conditions_list = []
      @ticket_conditions.each do |k, v|
        if (k != 'subject') && (k != 'only_pending')
          conditions_list << "(web_dialogs.#{k} = '#{v}')"
        end
      end
      if @ticket_conditions.key?('only_pending') && !@ticket_conditions['only_pending'].blank?
        conditions_list << "(web_dialogs.status IN (#{[SUPPORT_TICKET_CREATED, SUPPORT_TICKET_WAITING_REPLY].join(',')}))"
      end

      cond_str = [conditions_list.join(' AND ')] unless conditions_list.empty?
    end

    # if we need to search with a subject, use the ferret search. Otherwise, use the normal database query
    if !@ticket_conditions['subject'].blank?
      @pager = ::Paginator.new(@web_support.web_dialogs.find_by_contents(params[:subject], { limit: :all }, conditions: cond_str).length, PER_PAGE) do |offset, per_page|
        @web_support.web_dialogs.find_by_contents(params[:subject],
                                                  { limit: per_page, offset: offset, order: 'web_dialogs.id DESC' },
                                                  conditions: cond_str)
      end
    else
      web_dialogs = @web_support.web_dialogs.where(cond_str)
      @pager = ::Paginator.new(web_dialogs.count, PER_PAGE) do |offset, per_page|
        web_dialogs.limit(per_page).offset(offset).order('web_dialogs.id DESC')
      end
    end

    @web_dialogs = @pager.page(params[:page])
    @list_of_pages = []
    for idx in 1..@pager.number_of_pages
      @list_of_pages << idx
    end
    @show_number_of_pages = (@pager.number_of_pages > 1)

    @client_departments = @web_support.client_departments
  end

  def new_department
    @client_department = ClientDepartment.new(translation_status_on_create: TRANSLATION_PENDING_CLIENT_REVIEW)
    @languages = Language.list_major_first
    @action = :create_department
    @submit_text = _('Create this department')
    @header = _('Create a new department for support center %s') % @web_support.name
  end

  def create_department
    @client_department = ClientDepartment.new(params[:client_department])
    @client_department.web_support = @web_support
    if @client_department.save
      redirect_to action: :show
    else
      @languages = Language.list_major_first
      @action = :create_department
      @submit_text = _('Create this department')
      @header = _('Create a new department for support center %s') % @web_support.name
      render action: :new_department
    end
  end

  def edit_department
    @languages = Language.list_major_first
    @action = :update_department
    @submit_text = _('Update this department')
    @header = _('Edit department for support center %s') % @web_support.name
    render action: :new_department
  end

  def delete_department
    @client_department.destroy
    redirect_to action: :departments, id: @web_support.id
  end

  def update_department
    if @client_department.update_attributes(params[:client_department])
      redirect_to action: :departments
    else
      @languages = Language.list_major_first
      @action = :update_department
      @submit_text = _('Update this department')
      @header = _('Edit department for support center %s') % @web_support.name
      render action: :edit_department
    end
  end

  # ------------ branding -----------
  def add_branding
    language_id = params[:language_id].to_i
    msg = nil
    if language_id == 0
      msg = _('You need to select a language to customize the appearance for')
    else
      @branding = Branding.new(language_id: language_id)
      @branding.owner = @web_support
      @edit_branding = true

      existing_language_ids = @web_support.brandings.where('language_id IS NOT NULL').map(&:language_id)
      existing_language_ids << language_id

      # remove this language from the existing language IDs to add
      @available_branding_languages = Language.list_major_first(existing_language_ids)
    end
    @msg = msg
  end

  def edit_branding
    req = params[:req]
    lang = params[:language_id]
    if (req == 'show') || req.nil?
      cond = { 'language_id' => lang }
      @branding = @web_support.brandings.where(cond).first
      if @branding.nil?
        @branding = Branding.new(language_id: lang)
        @branding.owner = @web_support
      end
    end

    @edit_branding = true if req == 'show'

    if req.nil?
      unless @branding.update_attributes(params[:branding])
        # if !@branding.save
        @edit_branding = true
      end
    end

    if @branding
      logger.info "------------- replacing DIV:#{@branding.lang_div}"
    else
      logger.info '------------- NO BRANDING!'
    end
  end

  def del_branding
    lang = params[:language_id]
    if lang
      cond = { 'language_id' => lang }
      @branding = @web_support.brandings.where(cond).first
      @branding.destroy if @branding
    end
  end

  def confirm_delete_dialogs
    @return_to = params[:return_to]

    @web_dialogs = []
    params.each do |param, value|
      next unless (param[0...9] == 'WebDialog') && !value.blank?
      id = param[9..-1].to_i
      next unless id > 0
      web_dialog = WebDialog.find(id)
      if web_dialog.client_department.web_support == @web_support
        @web_dialogs << web_dialog
      end
    end
    if @web_dialogs.empty?
      flash[:notice] = _('No tickets selected to delete')
      if !@return_to.blank?
        redirect_to Rails.application.routes.recognize_path(@return_to)
      else
        redirect_to action: :index
      end
      return
    end

    @pre_select = true
    @header = _('Confirm deleting the following %d ticket(s)')
  end

  def delete_dialogs
    return_to = params[:return_to]

    web_dialogs = []
    params.each do |param, value|
      next unless (param[0...9] == 'WebDialog') && !value.blank?
      id = param[9..-1].to_i
      next unless id > 0
      web_dialog = WebDialog.find(id)
      if web_dialog.client_department.web_support == @web_support
        web_dialogs << web_dialog
      end
    end

    web_dialogs.each do |web_dialog|
      web_dialog.destroy
      logger.info "--------- Deleting WebDialog.#{web_dialog.id} ----------- "
    end

    flash[:notice] = if !web_dialogs.empty?
                       _('Deleted %s tickets') % web_dialogs.length
                     else
                       _('No tickets selected to delete')
                     end

    if !return_to.blank?
      redirect_to Rails.application.routes.recognize_path(return_to)
    else
      redirect_to action: :index
    end
  end

  private

  def locate_web_support

    @web_support = WebSupport.find(params[:id].to_i)
  rescue
    set_err('Cannot find this support center')
    return false

  end

  def locate_department

    @client_department = ClientDepartment.find(params[:department_id].to_i)
  rescue
    set_err('Cannot find this department')
    return false

  end
end
