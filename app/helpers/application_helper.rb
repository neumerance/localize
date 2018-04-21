# Methods added to this helper will be available to all templates in the application.
module ApplicationHelper
  def revision_type(rev)
    if rev.cms_request
      if rev.cms_request.website.cms_kind == CMS_KIND_WORDPRESS
        'Wordpress'
      else
        'Drupal'
      end
    elsif rev.project.kind == TA_PROJECT
      if rev.project.source == 0
        'Static Website'
      elsif rev.project.source == MANUAL_PROJECT
        'Help & Manual'
      else
        'Practice Project'
      end
    elsif rev.project.kind == MANUAL_PROJECT
      'Document'
    elsif rev.project.kind == SIS_PROJECT
      'Sizulizer'
    end
  end

  def tooltip(content, show_to_supporters = false)
    if show_to_supporters || !@user.try(:has_supporter_privileges?)
      content_tag(:div, class: 'help-wrapper') do
        content_tag(:span, class: 'help') do
          concat image_tag('qm.png')
          concat content_tag(:span, class: 'help-popup animated') {
            content.html_safe
          }
        end
      end
    end
  end

  def bid_status_text(bid)
    case bid.status
    when BID_GIVEN then
      'Bid given'
    when BID_ACCEPTED then
      'Bid accepted'
    when BID_COMPLETED then
      'Bid completed'
    when BID_WAITING_FOR_PAYMENT then
      'Bid waiting for payment'
    when BID_REFUSED then
      'Bid refused'
    when BID_CANCELED then
      'Bid canceled'
    when BID_TERMINATED then
      'Bid terminated'
    when BID_DECLARED_DONE then
      'Bid declared done'
    else
      raise "Bid status not found: #{bid.status}"
    end
  end

  def page_title
    'ICanLocalize'
  end

  def item_url_arguments(item, user = nil)
    for_supporter = user ? user.has_supporter_privileges? : false
    controller = for_supporter ? "/#{item[1]}" : item[1]
    action = if item.length >= 3
               item[2]
             else
               :index
             end
    if item.length >= 4
      if item[3].class == 1.class
        id = item[3]
        return { controller: controller, action: action, id: id }
      else
        return { controller: controller, action: action }.merge(item[3])
      end
    else
      return { controller: controller, action: action }
    end

  end

  def top_menu(user = nil)
    return unless @top_bar

    res = '<div id="navigationtabbar"><table border="0" cellspacing="0" cellpadding="0"><tr>'
    first = true
    for tab in @top_bar
      selected = tab[0]
      url_arguments = item_url_arguments(tab[1], user)
      res += '<td class="toptabspaces"></td>' unless first

      this_tab_html = if selected
                        '<td class="toptabhighlighted">' \
                          '<table width="100%" border="0" cellspacing="0" cellpadding="0"><tr>' \
                          '<td class="tableleftwallselected"></td>' \
                          '<th align="center" class="lmarg4 rmarg4 tabtexthighlighted">' +
                          link_to(tab[1][0], url_arguments, class: 'tabtexthighlighted') +
                          '</th><td class="tablerightwallselected"></td></tr></table></td>'
                      else
                        '<td class="toptab">' \
                          '<table width="100%" border="0" cellspacing="0" cellpadding="0"><tr>' \
                          '<td class="tableleftwall"></td>' \
                          '<th align="center" class="lmarg4 rmarg4 tabtext">' +
                          link_to(tab[1][0], url_arguments, class: 'tabtext') +
                          '</th><td class="tablerightwall"></td></tr></table></td>'
                      end

      res += this_tab_html
      first = false
    end
    res += '</tr></table></div>'
    res.html_safe
  end

  def second_menu
    return unless @bottom_bar

    res = '<div id="navigationbar">'
    first = true
    for location in @bottom_bar
      selected = location[0]
      res += '&nbsp;&nbsp;|&nbsp;&nbsp;' unless first
      if selected
        res += '<span class="navigationbar_current">' + location[1][0] + '</span>'
      else
        url_arguments = item_url_arguments(location[1])
        res += link_to(location[1][0], url_arguments)
      end
      first = false
    end
    res += '</div>'
    res.html_safe
  end

  def vacation_text(user)
    return '' unless user.on_vacation?
    content_tag(:span) do
      concat ' '.html_safe
      if @user.has_supporter_privileges?
        content_tag(:span, class: 'warning') do
          " (#{_('on planned leave')} - from #{user.current_vacation.beginning.strftime('%b %dth, %Y')} to #{user.current_vacation.ending.strftime('%b %dth, %Y')})"
        end
      else
        content_tag(:span, class: 'warning') do
          " #{_('on planned leave')} until #{user.current_vacation.ending.strftime('%b %dth, %Y')}"
        end
      end
    end
  end

  def user_link(user, show_vacation = true, show_session = true)
    return '' unless user
    user = OpenStruct.new(user) if user.is_a? Hash
    logged_in = false
    on_vacation = false
    content_tag(:span) do
      if !user
        'Deleted'
      elsif user[:type] == 'Root'
        name = content_tag(:strong, 'ICanLocalize')
      elsif user == @user
        name = content_tag(:strong, 'You')
      elsif !user.nickname.blank?
        name = user.nickname
        logged_in = user.logged_in? if show_session
        on_vacation = user.on_vacation? if show_vacation
      else
        name = user.fname + ' ' + user.lname
      end

      if @user && @user.has_supporter_privileges? && ((user[:type] == 'Client') || (user[:type] == 'Translator') || (user[:type] == 'Partner'))
        user_type = " (#{user[:type]})"
      end

      make_link = !user.has_supporter_privileges? && (!@user || (user.id != @user.id))
      title = !user.country.blank? ? user.country.nname : nil
      if show_session && logged_in
        title = '' if title.blank?
        title += ' (' + _('logged in') + ')'
      end

      concat link_to_if(make_link, name, { controller: '/users', action: :show, id: user.id }, title: title)
      concat user_type

      if @user.has_supporter_privileges? && user != @user
        concat " - #{link_to('switch', controller: '/login', action: :switch_user, id: user.id)}".html_safe
      end

      concat vacation_text(user) if show_vacation && on_vacation

      if user.has_supporter_privileges?
        concat "(#{_('support')})"
      elsif @user && (@user[:type] != user[:type]) && !@user.has_supporter_privileges?
        if user.is_bookmarked?(@user)
          concat image_tag('icons/star16.png', width: 16, height: 16, alt: 'bookmarked')
        else
          concat content_tag(:span, class: 'comment') {
            link_to({ controller: :bookmarks, action: :new, bookmark_user_id: user.id }, target: '_blank') do
              image_tag('icons/hollowstar_16.png', width: 16, height: 16, alt: 'add bookmark', title: 'Bookmark this user and leave public feedback', border: 0)
            end
          }
        end
      end
    end
  end

  def project_link(project)
    link_to_if((params[:controller] != 'projects') || (@project != project), project.name, controller: :projects, action: :show, id: project.id)
  end

  def revision_link(revision)
    link_to_if((params[:controller] != 'revisions') || (@revision != revision), revision.name, controller: :revisions, action: :show, id: revision.id, project_id: revision.project_id)
  end

  def create_chat_link(txt, revision)
    link_to(txt, controller: :chats, action: :create, project_id: revision.project.id, revision_id: revision.id, _method: :post)
  end

  def chat_link(chat, txt, aname = nil)
    link_to_if((params[:controller] != 'chats') || (@chat != chat), txt, controller: :chats, action: :show, id: chat.id, revision_id: chat.revision.id, project_id: chat.revision.project.id, anchor: aname)
  end

  def bid_link(bid, txt = nil)
    txt = bid.revision_language.language.name unless txt
    link_to_if((params[:controller] != 'bids') || (@bid != bid), txt, controller: :bids, action: :show, id: bid.id, chat_id: bid.chat.id, revision_id: bid.chat.revision.id, project_id: bid.chat.revision.project.id)
  end

  def show_project_path
    items = []
    cont = params[:controller]
    act = params[:action]
    if %w(projects revisions chats arbitrations bids).include? cont
      if @user
        if @user[:type] == 'Client' || @user[:type] == 'Alias'
          if @project && @project.id
            items << link_to(_('All projects'), controller: :projects, action: :index)
            items << project_link(@project)
            if @revision
              items << _('Revision').html_safe + ' '.html_safe + revision_link(@revision)
              if @chat
                items << _('Communication with').html_safe + ' '.html_safe + chat_link(@chat, @chat.translator.full_name)
                if @bid
                  items << _('Bid on').html_safe  + ' '.html_safe + bid_link(@bid)
                end
              end
            end
          end
        elsif @user[:type] == 'Translator'
          if @project
            items << @project.name
            if @revision
              items << _('Revision').html_safe + ' ' + revision_link(@revision)
              if @chat
                items << chat_link(@chat, _('Communication with client'))
                if @bid
                  items << _('Bid on').html_safe  + ' '.html_safe + bid_link(@bid)
                end
              end
            end
          end
        elsif @user.has_admin_privileges?
          if @project
            items << "#{user_link(@project.client)}'s projects"
            items << project_link(@project)
            if @revision
              items << _('Revision').html_safe + ' '.html_safe + revision_link(@revision)
              if @chat
                items << _('Communication with').html_safe + ' ' + chat_link(@chat, @chat.translator.full_name)
                if @bid
                  items << _('Bid on').html_safe  + ' '.html_safe + bid_link(@bid)
                end
              end
            end
          end
        end
      end

    elsif %w(websites website_translation_offers website_translation_contracts cms_requests shortcodes).include?(cont)
      if @user && (@user.has_supporter_privileges? || (@user[:type] == 'Client' || @user[:type] == 'Alias'))
        if @website && !@website.id.blank?
          if @user.has_supporter_privileges?
            items << link_to('Projects', controller: :supporter, action: :projects)
          elsif !@compact_display
            items << link_to(_('CMS translation projects'), controller: '/wpml/websites')
          end
          items << link_to_if(@website_translation_offer || cont == 'shortcodes' || %w(cms_requests websites).include?(cont), _('Project "%s"') % @website.name, controller: '/wpml/websites', action: :show, id: @website.id)
          items << _('Search Job') if cont == 'websites' && act == 'search_cms'
          if (cont == 'websites') && (act == 'comm_errors')
            items << _('Communication errors')
          elsif cont == 'cms_requests'
            items << link_to_if(@cms_request, _('Translation jobs'), controller: :cms_requests, action: :index, website_id: @website.id)
            items << _('Details') if @cms_request && !@cms_request.id.blank?
          elsif @website_translation_offer && !@website_translation_offer.id.blank?
            items << link_to_if(@website_translation_contract, @website_translation_offer.language_pair, controller: :website_translation_offers, action: :show, website_id: @website.id, id: @website_translation_offer.id)
            if @website_translation_contract && !@website_translation_contract.id.blank?
              items << _('Chat with %s') % @website_translation_contract.translator.full_name
            end
          end
          items << _('Shortcodes') if cont == 'shortcodes'
        elsif (cont == 'websites') && ((act == 'new') || (act == 'create') || (act == 'cms_requests') || (act == 'all_comm_errors'))
          items << link_to(_('CMS translation projects'), controller: '/wpml/websites')
          items << if (act == 'new') || (act == 'create')
                     _('New')
                   elsif act == 'cms_requests'
                     _('Summary of all translation jobs')
                   else
                     _('Communication errors')
                   end
        end
      elsif @user && (@user[:type] == 'Translator')
        if @website_translation_contract
          items << link_to(_('Home'), controller: :translator) << content_tag(:span) { concat _('%s') % @website.name; concat ' &raquo; '.html_safe; concat _('%s') % @website_translation_offer.language_pair }
        elsif @cms_request
          items << link_to(_('Home'), controller: :translator) << h(@cms_request.title)
        elsif act == 'review'
          items << 'Review position'
        end
      end
    elsif (cont == 'text_resources') || (cont == 'resource_chats') || (cont == 'resource_strings') || (cont == 'resource_uploads') || (cont == 'resource_translations') || (cont == 'resource_downloads')
      if @user[:type] == 'Client'
        items << link_to('Software localization projects', controller: :text_resources, action: :index)
      end
      if @text_resource && !@text_resource.id.blank?
        items << link_to_if((cont != 'text_resources') || (act != 'show'), h(@text_resource.name), controller: :text_resources, action: :show, id: @text_resource.id)
        if @resource_chat && !@resource_chat.id.blank?
          items << _('%s to %s') % [@text_resource.language.nname, @resource_chat.resource_language.language.nname]
        end
        if (cont == 'resource_strings') && (act == 'show')
          items << link_to('Strings for translation', controller: :resource_strings, action: :index, text_resource_id: @text_resource.id)
          items << @header if @resource_string && !@resource_string.blank?
        end
        items << @header if act != 'show'
      end
    elsif (cont == 'finance') && ((act == 'invoice') || (act == 'invoices') || (act == 'account_history') || (act == 'deposits') || (act == 'payment_methods'))
      items << link_to(_('My Account'), controller: :users, action: :my_profile) << link_to(_('Payments and withdrawals'), controller: :finance, action: :index) << @header
    elsif (cont == 'users') && ((act == 'translator_languages') || (act == 'verification') || (act == 'request_practice_project') || (act == 'setup_practice_project'))
      items << link_to(_('My Account'), controller: :users, action: :my_profile) << link_to(_('Profile'), controller: :users, action: :show, id: @user.id) << @header
    elsif (cont == 'web_supports') && @web_support && !@web_support.id.blank? && (act != 'show')
      items << link_to(@web_support.name, controller: :web_supports, action: :show, id: @web_support.id) << h(@header)
    elsif cont == 'web_dialogs'
      items << link_to(@web_dialog.client_department.web_support.name, controller: :web_supports, action: :show, id: @web_dialog.client_department.web_support.id) << link_to(_('Tickets for %s department') % h(@web_dialog.client_department.name), controller: :web_supports, action: :browse_tickets, id: @web_dialog.client_department.web_support.id, client_department_id: @web_dialog.client_department_id, set_args: 1) << h(@header)
    elsif (cont == 'web_messages') && (act != 'index')
      items << link_to(_('Instant Translation projects'), controller: :web_messages, action: :index)
      if act == 'review'
        items << link_to('job #%d' % @web_message.id, controller: :web_messages, action: :show, id: @web_message.id)
      end
      items << h(@header)
    elsif cont == 'private_translators'
      if (@user[:type] == 'Translator') && @private_translator
        items << link_to(_('All invitations'), controller: :private_translators, action: :clients) << _('Invitation by %s') % @private_translator.client.nickname
      end
    elsif (cont == 'vacations') && @auser
      items << link_to(_('Leaves for %s') % @auser.full_name, controller: :vacations, action: :index, user_id: @auser.id) << h(@header)
    elsif (cont == 'issues') && (act != 'index')
      items << link_to(_('Issues'), controller: :issues, action: :index) << h(@header)
    elsif %w(translation_analytics translation_analytics_preferences).include? cont
      items << link_to(_('Translation Dashboard'), controller: :translation_analytics, action: :index)

      case act
      when 'overview'
        items << link_to(_('Overview'), params.merge(controller: :translation_analytics, action: :overview))
      when 'details'
        items << link_to(_('Details'), params.merge(controller: :translation_analytics, action: :details))
      when 'deadlines'
        items << link_to(_('Deadlines'), params.merge(controller: :translation_analytics, action: :deadlines))
      when 'progress_graph'
        items << link_to(_('Progress Graph'), params.merge(controller: :translation_analytics, action: :progress_graph))
        if params[:language_id] && (params[:language_id].to_i != 0)
          items << link_to(Language.find(params[:language_id]).name, params.merge(controller: :translation_analytics, action: :progress_graph))
        end
      when 'edit' # translation_analytics_preferences
        items << link_to(_('Alerts'), params.merge(controller: :translation_analytics_preferences, action: :edit))
      end

    end

    unless items.empty?
      items[-1] = ''.html_safe + content_tag(:strong, items[-1])
      content_tag(:div, id: 'projectpathbar') do
        items.join(' > ').html_safe
      end
    end
  end

  def disp_time(tm)
    tm.strftime(TIME_FORMAT_STRING)
  rescue
    '---'
  end

  def disp_date(tm)
    tm.strftime(DATE_FORMAT_STRING)
  rescue
    '---'
  end

  def one_column_header(txt)
    content_tag(:div, txt, class: 'forumheadlineG')
  end

  def two_column_header(left, right)
    content_tag(:div) do
      concat content_tag(:div, class: 'forumheadlineGL') {
        concat image_tag('spacer.gif', width: 10, height: 1, alt: '')
        concat left
      }
      concat content_tag(:div, class: 'forumheadlineGR') {
        concat image_tag('spacer.gif', width: 10, height: 1, alt: '')
        concat right
      }
    end
  end

  def two_column_row(left, right)
    content_tag(:div) do
      concat content_tag(:div, class: 'forumLeftWhite') {
        content_tag(:div, class: 'content') do
          left.html_safe
        end
      }
      concat content_tag(:div, class: 'forumRightWhite') {
        content_tag(:div, class: 'content') do
          right.html_safe
        end
      }
      concat content_tag(:div, '', class: 'clear')
    end
  end

  def bookmark_user_link(auser)
    return nil if auser == @user
    return nil if auser[:type] == @user[:type]

    if @user.bookmarks.find_by(resource_id: @user.id, resource_type: 'User')
      return nil
    end

    content_tag(:p) do
      concat image_tag('icons/star.png', class: 'left_icon')
      concat link_to(_("Add #{auser.full_name} to my bookmarks (and leave public feedback)"), controller: :bookmarks, action: :new, bookmark_user_id: auser.id)
    end
  end

  def my_error_messages_for(*params)
    object = params.collect { |object_name| instance_variable_get("@#{object_name}") }.compact.first
    return unless object

    if object.errors.any?
      header = n_('Found a problem', 'Found %{num} problems', object.errors.count) % { num: object.errors.count }
      create_error_messages(object, header)
    end
  end

  def error_messages_for(*params)
    object = params.collect { |object_name| instance_variable_get("@#{object_name}") }.compact.first
    if object.errors.any?
      header = pluralize(object.errors.count, 'error') + ' prevented this record from being saved:'
      create_error_messages(object, header)
    end
  end

  def object_errors_messages(object)
    content_tag(:ul, object.errors.full_messages.map { |msg| content_tag(:li, msg) })
  end

  def link_to_unless_same(txt, url)
    link_to_if(request.url != url, txt, url)
  end

  def bool_to_yes_no(val)
    if val == 1
      _('Yes')
    else
      _('No')
    end
  end

  def arbitration_description(arbitration)
    txt = if Arbitration::ARBITRATION_TYPE_TEXT.key?(arbitration.type_code)
            Arbitration::ARBITRATION_TYPE_TEXT[arbitration.type_code]
          else
            _('Arbitration')
          end
    content_tag(:span) do
      concat "#{txt} "
      concat ' '.html_safe + _('between') + ' '.html_safe
      concat user_link(arbitration.initiator)
      concat ' '.html_safe + _('and') + ' '.html_safe
      concat user_link(arbitration.against)
    end
  end

  def languages_table(languages, orig_lang = nil, display_prices = true, show_proofreading = true)
    max_cols = 4
    languages_names = languages.keys.sort

    if orig_lang
      avail_langs = AvailableLanguage.where(from_language_id: orig_lang.id)
      price = {}
      avail_langs.each { |x| price[x.to_language_id] = x.price_for(@user) }
      languages_names.delete(orig_lang.name) unless show_proofreading
    end

    col_count = 0
    res = '<table class="languages"><tr>'
    for lang_name in languages_names
      lang = languages[lang_name]
      next unless lang[2] == 1
      if col_count == max_cols
        res << '</tr><tr>'
        col_count = 0
      end
      res << '<td>'
      disp_name = "<strong>#{lang_name}</strong>"

      if display_prices && price[languages[lang_name][0]]
        disp_name << "<span style='font-size: 85%; color: #606060;'> $#{price[languages[lang_name][0]]} </span>"
      end

      if orig_lang && (orig_lang.name == lang_name)
        disp_name << '<br /><span class="comment">(proofreading)</span>'
      end
      res << '<label>' + check_box_tag("language[#{lang[0]}]", '1', lang[1]) + "&nbsp; #{disp_name}</label>"
      col_count += 1
      res << '</td>'
    end

    for idx in col_count..(max_cols - 1)
      res << '<td></td>'
    end
    res << '</tr><tr>'
    col_count = 0
    first = true

    for lang_name in languages_names
      lang = languages[lang_name]
      next unless lang[2] == 0
      if col_count == max_cols
        res << '</tr><tr>'
        col_count = 0
        first = false
      end
      res << if first
               '<td class="sep">'
             else
               '<td>'
             end
      disp_name = lang_name
      if display_prices && price[languages[lang_name][0]]
        disp_name += "<span style='font-size: 85%; color: #606060;'> $#{price[languages[lang_name][0]]} </span>"
      end
      if orig_lang && (orig_lang.name == lang_name)
        disp_name += '<br /><span class="comment">(proofreading)</span>'
      end
      res << '<label>' + check_box_tag("language[#{lang[0]}]", '1', lang[1]) + "&nbsp; #{disp_name}</label>"
      col_count += 1
      res << '</td>'
    end
    for idx in col_count..(max_cols - 1)
      res << '<td></td>'
    end
    res << '</tr></table>'
    res
  end

  def put_object_id(object)
    "#{object.class}#{object.id}"
  end

  def object_div(object, options = '')
    '<div id="' + put_object_id(object) + '" ' + options + '>'
  end

  def named_div(name, num)
    '<div id="' + name + num.to_s + '">'
  end

  def infotab_top(title, description)
    content_tag(:table, width: '100%', border: 0, cellspacing: 0, cellpadding: 0) do
      content_tag(:tr) do
        content_tag(:td) do
          content_tag(:table, width: '100%', border: 0, cellspacing: 0, cellpadding: 0) do
            concat content_tag(:tr) {
              concat content_tag(:td, '', height: 27)
              concat content_tag(:td, width: 6, height: 55, rowspan: 2, align: 'center', valign: 'top', class: 'blockTab') {
                image_tag('tablightleft.jpg', width: 6, height: 6)
              }
              concat content_tag(:td, title.html_safe, width: 164, rowspan: 2, align: 'center', valign: 'top', class: 'blockTab tmarg7')
              concat content_tag(:td, width: 6, rowspan: 2, align: 'center', valign: 'top', class: 'blockTab') {
                image_tag('tablightright.jpg', width: 6, height: 6)
              }
            }
            concat content_tag(:tr) {
              content_tag(:td, description.html_safe, class: 'upperBlock', colspan: 4)
            }
          end
        end
      end
    end
  end

  def infotab_header(headings, attributes = {}, width = 100, table_attr = '', object = nil, opts = {})
    width_attr = width ? "width=\"#{width}%\"" : ''

    res = '<table %s %s cellspacing="0" cellpadding="3" class="stats"><tr class="headerrow">' % [width_attr, table_attr]
    res += '<th></th>' if opts[:blank_initial_col_header]
    headings.each do |heading|
      head_attr = ''
      if attributes.key?(heading)
        attributes[heading].each { |k, v| head_attr += ' ' + k + ' = "' + v + '"' }
      end
      tooltip_icon = tooltip("Review is performed by a second translator who proofreads the translation quality and checks that it's free of any typos or errors. Review costs 50% extra per word and it's optional.") if heading == 'Review' && object.is_a?(Website)
      res += "<th#{head_attr}>#{heading} #{tooltip_icon}</th>"
    end
    res += '</tr>'
    yield res if block_given?
    res.html_safe
  end

  def infotab_footer(txt = nil)
    res = '</table>'
    res += '<div class="tabbottom">' + txt + '</div>' if txt
    res
  end

  # Strip out not allowed tags like <script>
  def scrub(txt)
    scrubber = Rails::Html::TargetScrubber.new
    scrubber.tags = BLACKLIST_TAGS
    scrubber.attributes = BLACKLIST_ATTR

    html_fragment = Loofah.fragment(txt)
    html_fragment.scrub!(scrubber)
    html_fragment.to_s.html_safe
  end

  ICL_URLS = /http:\/\/www\.(icanlocalize|onthegosoft|onthegosystems)\.com[A-Za-z0-9_\-?&=#;.\/]*/
  def pre_format(txt, render_html = false)
    return unless txt

    # Escape html if we are not going to render html.
    txt = h(txt) unless render_html

    # This return links scapped, so even if render_html is false this method
    # returns and html string.
    txt = scrub('' + txt.gsub(ICL_URLS) { |url| concat link_to(url, url, target: '_blank') })

    content_tag(:span) do
      txt.split("\n").each do |str|
        str = str.html_safe if render_html || txt.html_safe
        concat content_tag(:span, (render_html ? str.html_safe : str))
        concat '<br />'.html_safe
      end
    end
  end

  def markup(txt)
    bc = BlueCloth.new(txt)
    bc.to_html
  end

  def infobar_contents(client_text, translator_text, show_icon = false, icon_ok = false)
    if @user[:type] == 'Translator'
      translator_text
    else
      txt = if show_icon
              if icon_ok
                '<img src="/assets/icons/selectedtick.png" class="left_icon" alt="ok" />'
              else
                '<img src="/assets/icons/important.png" class="left_icon" alt="warning" />'
              end
            else
              ''
            end
      txt + client_text
    end
  end

  def open_revision_translation_languages(revision)
    revision_languages = revision.revision_languages.includes(:language).where('NOT EXISTS( SELECT id FROM bids WHERE (bids.revision_language_id=revision_languages.id) AND (bids.won = 1))')
    unless revision_languages.empty?
      content_tag(:div) do
        concat 'Translation languages (open to bids): '
        concat content_tag(:ul) {
          revision_languages.each do |revision_language|
            concat content_tag(:li) {
              content_tag(:strong, revision_language.language.name)
            }
          end
        }
      end
    end
  end

  def revision_categories(revision)
    revision_categories = revision.revision_categories.includes(:category)
    content_tag(:ul) do
      if !revision_categories.empty?
        concat content_tag(:span, 'This project requires the following skilles:')
        concat content_tag(:ul) do
          revision_categories.each do |revision_category|
            concat content_tag(:li) do
              concat content_tag(:strong, revision_category.category.name.capitalize); concat ': '.html_safe
              concat content_tag(:span, revision_category.category.description)
            end
          end
        end
      else
        concat "This project doesn't require any specific fields of expertise."
      end
    end
  end

  def help_frame
    grouped_topics = {}
    group_keys = {}
    @help_placements.each do |help_placement|
      grouped_topics[help_placement.help_group.name] ||= []
      grouped_topics[help_placement.help_group.name] << help_placement.help_topic
      group_keys[help_placement.help_group.order] = help_placement.help_group.name
    end
    content_tag(:div, id: 'helpcontent') do
      group_keys.keys.sort.each do |order|
        name = group_keys[order]
        concat content_tag(:h4, name)
        concat content_tag(:ul, class: 'condensedlist') {
          grouped_topics[name].each do |help_topic|
            concat content_tag(:li, link_to(help_topic.title, help_topic.url, title: help_topic.summary, target: '_blank'))
          end
        }
      end
      if @user.is_a?(Translator) && @user.webta_enabled?
        concat content_tag(:h4, 'WebTA help')
        concat content_tag(:ul, class: 'condensedlist') {
          concat content_tag(:li, link_to('Documentation', 'http://docs.icanlocalize.com/information-for-translators/getting-started-with-webta/', title: 'Learn more about WebTA', target: '_blank'))
          concat content_tag(:li, link_to('Do a test project', @user.link_to_webta(CmsRequestFake.new(@user)), title: 'Test WebTA with a training project', target: '_blank'))
        }
      end
    end
  end

  def safe_format(str)
    h(str).gsub('[b]', '<b>').gsub('[/b]', '</b>')
  end

  def revision_summary(revision)
    items = ["Released to translators: #{bool_to_yes_no(revision.released)}",
             "Open to bids: #{bool_to_yes_no(revision.open_to_bids)}"]
    concat content_tag('ul', class: 'condensedlist') {
      items.each { |item| concat content_tag(:li, item) }
    }
    if revision.is_test == 1
      concat '<p class="warning">Test project</p>'.html_safe
    end
  end

  def revision_translation_summary(revision)
    content_tag(:ul, class: 'condensedlist') do
      revision.revision_languages.each do |revision_language|
        selected_bid = revision_language.selected_bid
        lang_details = revision_language.language.name + ': '
        concat content_tag(:li) {
          if selected_bid
            status_txt = Bid::BID_STATUS[selected_bid.status]
            if selected_bid.status == BID_DECLARED_DONE
              status_txt = content_tag(:span, status_txt, class: 'warning')
            end
            concat 'You selected '
            concat user_link(selected_bid.chat.translator)
            concat ' ('
            concat link_to('chat', controller: :chats, action: :show, project_id: revision.project_id, revision_id: revision.id, id: selected_bid.chat_id)
            concat ') '
            concat status_txt
          else
            concat 'No translator selected'
          end
        }
      end
    end
  end

  def user_todos_email_summary(user, problem_msg, html = false)
    active_items, todos = user.todos(TODO_STATUS_MISSING)
    content_tag(:div) do
      if active_items > 0
        if html
          concat content_tag(:p, "IMPORTANT: #{problem_msg}".html_safe)
          concat content_tag(:p, 'You need to:')
          concat content_tag(:ol) {
            todos.each do |todo|
              concat content_tag(:li, todo[1]) if todo[0] == TODO_STATUS_MISSING
            end
          }
          concat content_tag(:p, 'To complete your account setup, go to http://www.icanlocalize.com, and log in to your account.')
        else
          concat strip_tags("IMPORTANT: #{problem_msg} \n")
          concat "You need to: \n"
          todos.each do |todo|
            concat "* #{todo[1]} \n" if todo[0] == TODO_STATUS_MISSING
          end
          concat 'To complete your account setup, go to http://www.icanlocalize.com, and log in to your account.'
        end
      end
    end
  end

  def branded_logo
    if !@logo_url.blank? && !@home_url.blank?
      "<a href=\"#{@home_url}\">" + image_tag(@logo_url, size: @logo_size, style: 'float: left; margin-top: 0.3em; margin-bottom: 0.3em;', border: 0, alt: 'Home') + '</a>'
    elsif !@logo_url.blank?
      image_tag(@logo_url, size: @logo_size, style: 'float: left; margin-top: 0.3em; margin-bottom: 0.3em;', border: 0, alt: 'Home')
    end
  end

  def branded_home
    return link_to(_('Home'), @home_url) unless @home_url.blank?
  end

  def items_list(items)
    content_tag(:span) do
      items.each do |item|
        concat "#{item[0]}: "
        concat content_tag(:b, item[1])
        concat '<br/>'.html_safe
      end
    end
  end

  def ta_out_of_date_warning(user)
    last_ta_download = Download.where('(generic_name=?) AND (usertype=?)', TA_GENERIC_NAME, user[:type]).order('id DESC').first
    recent_user_ta_download = user.downloads.where('downloads.generic_name=?', TA_GENERIC_NAME).order('downloads.id DESC').first
    content_tag(:p) do
      if !recent_user_ta_download
        concat content_tag(:b) {
          concat image_tag('icons/important.png', size: '32x32', alt: 'Important', border: 0, align: 'middle')
          concat ' '.html_safe
          concat ( _('To begin translating, first %s.') % link_to(_('download Translation Assistant'), { controller: :downloads, action: :show_recent, id: TA_GENERIC_NAME }, target: '_blank')).html_safe
        }
      elsif recent_user_ta_download.id != last_ta_download.id
        concat content_tag(:b) {
          concat image_tag('icons/important.png', size: '32x32', alt: 'Important', border: 0, align: 'middle')
          concat ' '.html_safe
          concat ( _('Your version of Translation Assistant is out of date. Please %s and install the current version.') % link_to(_('download Translation Assistant'), { controller: :downloads, action: :show_recent, id: TA_GENERIC_NAME }, target: '_blank')).html_safe
        }
      else
        return ''
      end
    end
  end

  def printable_url
    if /\?/.match(request.url)
      request.url.gsub('&', '&amp;') + '&amp;printable=1'
    else
      request.url.gsub('&', '&amp;') + '?printable=1'
    end
  end

  def show_trail
    return '' unless @trail

    @trail.collect { |t| link_to_if(t[1] != {}, t[0], t[1]) }.join(' &gt; ')
  end

  def page_index(index_list)
    added_something = false
    res = content_tag(:div) do
      concat content_tag(:h3, 'On this page')
      concat content_tag(:ul) {
        index_list.each do |item|
          concat content_tag(:li, link_to(item[0], anchor: item[1]))
          added_something = true
        end
      }
    end
    added_something ? res : nil
  end

  def modern_message_container(messages)
    content_tag(:div) do
      concat link_to('', '', name: 'comments')
      messages.each do |message|
        concat content_tag(:div, class: 'boxshadow') {
          users = message.users
          delivery = if !users.empty?
                       content_tag(:span) do
                         concat _('from') + ' '
                         concat content_tag(:b, user_link(message.user) + ' ')
                         concat _('to') + ' '
                         concat content_tag(:span) {
                           content_tag(:b) do
                             users.each { |u| concat user_link(u) + (', ' unless u == users.last) }
                           end
                         }
                       end
                     else
                       content_tag(:b, user_link(message.user))
                     end
          concat content_tag(:div, delivery)
          concat content_tag(:div, class: 'txtblue dateDiv') {
            link_to(disp_time(message.chgtime), "##{put_object_id(message)}")
          }
          concat content_tag(:div, '', class: 'clear')
          concat content_tag(:p, class: 'margin-top-20') {
            message.body_with_emojis.split("\n").each do |str|
              concat content_tag(:span, auto_link(h(str)))
              concat '<br />'.html_safe
            end
          }
          concat content_tag(:div, '', class: 'clear')
          unless message.attachments.empty?
            concat '<br/><br/>'.html_safe
            concat content_tag(:div, class: 'infobox') {
              concat content_tag(:h4, _('Attachments'))
              message.attachments.each do |attachment|
                concat content_tag(:p) {
                  if %w(image/jpeg image/png image/jpeg image/tiff image/ief image/gif).include? attachment.content_type
                    link_to(attachment.filename, 'javascript:void(0)', onclick: "Modalbox.show('<img src=\"#{url_for(action: :attachment, id: attachment.message.owner_id, attachment_id: attachment.id)}\" style=\"width: 100%; display: block\">', {title: '#{attachment.filename}', width: '1200px'})")
                  else
                    link_to(attachment.filename, action: :attachment, id: attachment.message.owner_id, attachment_id: attachment.id)
                  end
                }
              end
            }
          end
        }
      end
    end
  end

  def legacy_message_container(messages)
    content_tag(:div, class: '') do
      concat link_to('', '', name: 'comments')
      messages.each do |message|
        concat content_tag(:div) {
          users = message.users
          delivery = if !users.empty?
                       content_tag(:span) do
                         concat _('from') + ' '
                         concat content_tag(:b, user_link(message.user) + ' ')
                         concat _('to') + ' '
                         concat content_tag(:span) {
                           content_tag(:b) do
                             users.each { |u| concat user_link(u) + (', ' unless u == users.last) }
                           end
                         }
                       end
                     else
                       content_tag(:b, user_link(message.user))
                     end
          concat content_tag(:div, id: put_object_id(message), class: 'messageTop') {
            concat content_tag(:div, delivery, class: 'nameDiv messageDivtl')
            concat content_tag(:div, class: 'txtblue dateDiv messageDivtr') {
              link_to(disp_time(message.chgtime), "##{put_object_id(message)}")
            }
            concat content_tag(:div, '', class: 'clear')
          }
          concat content_tag(:div, class: 'messageLeft') {
            concat content_tag(:div, '', class: 'clear')
            concat content_tag(:div, class: 'messageDiv') {
              concat content_tag(:p, class: 'padding-left-20 margin-top-20') {
                message.body_with_emojis.split("\n").each do |str|
                  concat content_tag(:span, h(str))
                  concat '<br />'.html_safe
                end
              }
            }
            concat content_tag(:div, '', class: 'clear')
            unless message.attachments.empty?
              concat '<br/><br/>'.html_safe
              concat content_tag(:div, class: 'infobox') {
                concat content_tag(:h4, _('Attachments'))
                message.attachments.each do |attachment|
                  concat content_tag(:p) {
                    link_to(attachment.filename, action: :attachment, id: attachment.message.owner_id, attachment_id: attachment.id)
                  }
                end
              }
            end
          }
          concat content_tag(:div, class: 'messageBottom') {
            concat content_tag(:div, ''.html_safe, class: 'messageDivbl', style: 'width: 10px; height: 10px')
            concat content_tag(:div, ''.html_safe, class: 'messageDivbr', style: 'width: 10px; height: 10px')
            concat content_tag(:div, '', class: 'clear')
          }
          concat content_tag(:div, '', class: 'spacerDiv')
        }
      end
    end
  end

  def show_messages(messages)
    unless messages.blank?
      content_tag(:div, style: 'margin-bottom: 30px;') do
        concat content_tag(:h2, _('Messages'))
        concat @is_modern ? modern_message_container(messages) : legacy_message_container(messages)
      end
    end
  end

  def show_reply(messages_exist, for_who = nil)
    form_tag({ action: :create_message }, multipart: true, remote: false) do
      res = '<table width="100%" cellspacing="0" cellpadding="0" border="0" class="chatcomments">
    <tr class="headerrow">
    <td class="tableleftwall"/>
    <th class="blockTab tmarg7" colspan="2">'
      res += messages_exist ? _('Reply') : _('Post first message')
      res += '</th>
    <td class="tablerightwall"/>
  </tr>
  <tr class="reply"><td colspan="4">&nbsp;</td></tr>
  <tr class="reply">
    <td></td>
    <td>' + _('Message:') + '</td>
    <td>'.html_safe + text_area_tag(:body, nil, cols: 70, rows: 10, style: 'width:100%', maxlength: COMMON_NOTE, required: true) + '</td>
    <td></td>
  </tr>
  <tr class="reply">
    <td></td>
    <td>' + _('Attachments') + ':</td>
    <td><div id="documents_to_upload"><p>' + file_field_tag('file1[uploaded_data]', size: 40, id: 'file1_uploaded_data', onchange: "validate_file_size('file1[uploaded_data]', '#{ATTACHMENT_MAX_SIZE}')") + '</p></div>
      <p><a href="#form_top" onclick="add_another_file(' + ATTACHMENT_MAX_SIZE.to_s + ');">' + _('Add another attachment') + '</a></p>
    </td>
    <td></td>
  </tr>
  <tr class="reply"><td colspan="4">&nbsp;</td></tr>
  <tr class="reply">
    <td></td>
    <td colspan="2">'
      if for_who
        for_who.delete(nil)
        res += hidden_field_tag('max_idx', for_who.length)
        if for_who.length == 1
          res += hidden_field_tag('for_who1', for_who[0].id)
        elsif for_who.length > 1
          idx = 0
          send_to_client = for_who.find_all(&:alias?).empty?

          for_who.each do |user|
            next unless user
            idx += 1
            checked = ((user.email != CMS_SUPPORTER_EMAIL) && (user.email != SYS_ADMIN_EMAIL)) || (for_who.length == 1)
            checked = false if (user.type == 'Client') && (!send_to_client || (@user.type == 'Alias'))
            res += content_tag(:p) do
              content_tag(:label) do
                concat check_box_tag("for_who#{idx}", user.id, checked)
                concat _('Notify '.html_safe + content_tag(:b, user.full_name) + vacation_text(user))
              end
            end
          end
        end
      end
      res += '<strong>How to use the chat</strong>'
      res += '<ul>'
      res += '<li>If someone requires technical help from support, please make sure to open a support ticket.</li>'
      res += '<li>All communication must remain in the system. Disclosing personal contact details is a breach of our T&C.</li>'
      res += '<li>Messages in projects are visible to ALL parties, but only users whose names are ticked will be notified personally if a new message is posted.</li>'
      res += '</ul>'.html_safe
      res += submit_tag(_('Make comment'), data: { disable_with: 'Make comment' })
      res += '</td>'
      res += '
          <td></td>
        </tr>
        <tr class="reply"><td colspan="4">&nbsp;</td></tr>
      </table>'
      res.html_safe
    end
  end

  def translation_language_stats(revision, nomarkup = false)
    return '' if !revision || (revision.kind == MANUAL_PROJECT)

    content_tag(:span) do
      if revision.language
        orig_language_name = revision.language.name
        if !revision.revision_languages.empty?
          if (revision.project.source == SIS_PROJECT) && (revision.versions.length >= 1)
            ol, lang_stats = revision.versions[0].get_sisulizer_stats
            lang_stats.each do |lang, stats|
              words_to_translate = (stats[WORDS_STATUS_NEW_CODE] || 0) + (stats[WORDS_STATUS_MODIFIED_CODE] || 0)
              if nomarkup
                concat "#{orig_language_name} to #{lang.name}: #{words_to_translate} words. \n"
              else
                concat content_tag(:b, orig_language_name)
                concat ' to '
                concat ': '
                concat content_tag(:b, lang.name)
                concat content_tag(:b, words_to_translate)
                concat ' words. <br />'.html_safe
              end
            end
          else
            revision.revision_languages.each do |rl|
              if nomarkup
                concat "#{orig_language_name} to #{rl.language.name}: #{revision.lang_word_count(rl.language)} words.\nf"
              else
                concat content_tag(:b, orig_language_name)
                concat ' to '
                concat content_tag(:b, rl.language&.name)
                concat ': '
                concat content_tag(:b, revision.try(:lang_word_count, rl.language))
                concat ' words. <br />'.html_safe
              end
            end
          end
        else
          if nomarkup
            concat "#{revision.lang_word_count(revision.language)} words in #{orig_language_name}. \n"
          else
            concat content_tag(:b, revision.lang_word_count(revision.language))
            concat ' words in '
            concat content_tag(:b, orig_language_name)
          end
        end
      end
    end
  end

  def revision_word_count(revision)
    return '' unless revision

    # orig_language_name = revision.language.name
    revision.lang_word_count(revision.language)
  end

  def compact_list(entries)
    current_count = 0
    l = entries.length
    cols = 4
    per_col = (1.0 * l / cols).ceil
    res = '<table width="100%"><tr>'
    (0...cols).each do |col|
      start = col * per_col
      fin = (col + 1) * per_col
      fin -= 1 if col < (cols - 1)

      res += '<td valign="top"><ul class="clear_list">'
      if (start < l) && (fin >= 0)
        res += ''.html_safe
        entries[start..fin].each do |entry|
          current_count += 1
          res += content_tag(:li, current_count.to_s + '. ' + link_to(entry[0], entry[1]), nil, false)
        end

      end
      res += '</ul></td>'
    end
    res += '</tr></table>'
    res.html_safe
  end

  def text_resource_languages_summary(text_resource)
    if !text_resource.resource_languages.empty?
      _('%s to %s') % [text_resource.language.name, (text_resource.resource_languages.collect { |rl| rl.language.name }).join(', ')]
    else
      text_resource.language.try(:name)
    end
  end

  def display_word_count(resource_language)
    word_count = resource_language.text_resource.count_words(resource_language.text_resource.unique_resource_strings, resource_language.text_resource.language, resource_language, false, 'all')
    if word_count > 0
      return "This project contains #{resource_language.text_resource.count_words(resource_language.text_resource.unique_resource_strings, resource_language.text_resource.language, resource_language, false, 'all')} words in #{resource_language.text_resource.unique_resource_strings.count} string(s)."
    else
      return 'No strings sent to translation yet'
    end
  end

  def cms_request_details(cms_request)
    content_tag(:ul) do
      cms_request.cms_target_languages.each do |tl|
        concat content_tag(:li, "#{Language.cached_language(cms_request.language_id).nname} > #{Language.cached_language(tl.language_id).nname}: #{_(CmsTargetLanguage::STATUS_TEXT[tl.status])}")
      end
    end
  end

  def language_dir_css_attribute(language)
    language.rtl == 1 ? 'direction:rtl;' : 'direction:ltr;'
  end

  def text_flow_css_attribute(language)
    language.rtl == 1 ? 'text-align:right;' : ''
  end

  def display_chrome_warning
    user_agent = request.env['HTTP_USER_AGENT']
    if !user_agent.blank? && !user_agent.downcase.index('chrome').nil?
      return '<div style="margin: 1em 2em 2em 2em; padding: 1em; border: 1pt solid #FF0000; background-color: #FFF4F4;">File uploads do not work correctly with Google Chrome. We recommend that you try a different browser.</div>'
    else
      return ''
    end
  end

  def csv_url
    if /\?/.match(request.url)
      request.url.gsub('&', '&amp;') + '&amp;cvsformat=1'
    else
      request.url.gsub('&', '&amp;') + '?cvsformat=1'
    end
  end

  def display_stats_with_destination_languags(word_count, show_cost_estimate)

    res = infotab_header(['Target language', 'Words to translate'] + (show_cost_estimate ? ['Estimated payment'] : []))

    total_payment = 0
    word_count.each do |to_lang, stats|
      res += "<tr><td>#{to_lang.name}</td>"

      word_to_translate = (stats[WORDS_STATUS_NEW_CODE] || 0) + (stats[WORDS_STATUS_MODIFIED_CODE] || 0)
      res += "<td>#{word_to_translate}</td>"

      if show_cost_estimate
        language_payment = word_to_translate * WebMessage.price_per_word_for(@user)
        res += '<td>%.2f USD</td>' % language_payment
        total_payment += language_payment
      end
      res += '</tr>'
    end
    if show_cost_estimate
      res += '<tr><td><b>Total</b></td><td></td><td><b>%.2f USD</b></td></tr>' % total_payment
    end
    res += '</table>'
    res
  end

  def set_focus_to_id(id)
    javascript_tag("jQuery('##{id}').focus()")
  end

  def select_id(id)
    javascript_tag("jQuery('##{id}').select()")
  end

  def user_accounts(money_accounts)
    content_tag(:span) do
      money_accounts.each do |user_account|
        concat link_to("#{user_account.currency.name} account", controller: :finance, action: :account_history, id: user_account.id)
      end
    end
  end

  def users_list(users)
    content_tag(:table, class: 'stats', style: 'width: 100%') do
      concat content_tag(:tr, class: 'headerrow') {
        concat content_tag(:th, 'Type')
        concat content_tag(:th, 'Nickname')
        concat content_tag(:th, 'Fname')
        concat content_tag(:th, 'Lname')
        concat content_tag(:th, 'Email')
        concat content_tag(:th, 'Userstatus')
        concat content_tag(:th, 'Nationality')
        concat content_tag(:th, 'Money accounts')
        concat content_tag(:th, 'Signup date')
        concat content_tag(:th, 'Source')
        concat content_tag(:th, 'Locale')
        concat content_tag(:th, 'Actions', colspan: 2)
      }
      users.each do |user|
        concat content_tag(:tr) {
          concat content_tag(:td, user[:type])
          concat content_tag(:td, link_to(user.nickname, user_path(user)))
          concat content_tag(:td, user.fname)
          concat content_tag(:td, user.lname)
          concat content_tag(:td, user.email)
          concat content_tag(:td, User::USER_STATUS_TEXT[user.userstatus])
          concat content_tag(:td, !user.country.blank? ? user.country.name : ((user[:type] == 'Translator') && (user.userstatus == USER_STATUS_QUALIFIED) && user.verified? ? content_tag(:span, 'Unknown', class: 'warning') : content_tag(:span, 'Unknown', class: 'comment')))
          concat content_tag(:td, %w(Client Translator Partner).include?(user[:type]) ? user_accounts(user.money_accounts) : '')
          concat content_tag(:td, disp_date(user.signup_date))
          concat content_tag(:td) {
            if !user.source.blank?
              (user.source.starts_with?('http') ? link_to(truncate(user.source[7..-1], length: 25, omission: '...'), user.source) : truncate(user.source, length: 25, omission: '...'))
            else
              ''
            end
          }
          concat content_tag(:td, user.loc_code)
          concat content_tag(:td, link_to('Show', user_path(user)))
          concat content_tag(:td, link_to('Edit', edit_user_path(user)))
        }
      end
    end
  end

  def glossary_terms
    glossary_terms = @glossary_client.glossary_terms.includes(:glossary_translations).order('glossary_terms.id ASC')
    languages = []
    table_rows = []
    glossary_terms.each do |glossary_term|
      cols = {}
      glossary_term.glossary_translations.each do |glossary_translation|
        unless languages.include?(glossary_translation.language)
          languages << glossary_translation.language
        end
        cols[glossary_translation.language] = glossary_translation.txt
      end
      table_rows << [glossary_term, cols]
    end
    res = [infotab_header(%w(Term Description) + languages.collect(&:name))]
    table_rows.each do |table_row|
      res << "<tr><td>#{table_row[0].txt}</td><td>#{table_row[0].description}</td>"
      languages.each do |language|
        res << '<td>' + (table_row[1][language] || '') + '</td>'
      end
      res << '</tr>'
    end
    res << '</table>'
    res.join
  end

  def glossary_edit_list
    language_ids = @glossary_languages.collect(&:id)

    highlight_txt = nil
    if @locate && @glossary_term
      highlight_txt = @glossary_term.txt.downcase
      glossary_terms = @glossary_client.glossary_terms.includes(:glossary_translations).where('glossary_terms.txt LIKE ?', highlight_txt).order('glossary_terms.txt')
      glossary_terms += @glossary_client.glossary_terms.includes(:glossary_translations).where('glossary_terms.txt NOT LIKE ?', highlight_txt).order('glossary_terms.txt')
    else
      glossary_terms = @glossary_client.glossary_terms.includes(:glossary_translations).order('glossary_terms.txt')
    end

    table_rows = []
    glossary_terms.each do |glossary_term|
      cols = {}
      glossary_term.glossary_translations.each do |glossary_translation|
        if language_ids.include?(glossary_translation.language.id)
          cols[glossary_translation.language] = glossary_translation
        end
      end
      table_rows << [glossary_term, cols]
    end
    res = [infotab_header(%w(Language Term Description) + @glossary_languages.collect(&:name))]
    unless table_rows.blank?
      table_rows.each do |table_row|
        glossary_term = table_row[0]
        td_style = if highlight_txt && (glossary_term.txt.downcase == highlight_txt)
                     'style="font-weight: bold; background-color:#E0FFE0;"'
                   else
                     ''
                   end

        res << "<tr id=\"glossary_term#{table_row[0].id}\">"
        res << "<td #{td_style}><span class=\"comment\">#{pre_format(table_row[0].language.try(:name))}</span></td>"
        res << "<td #{td_style}>#{link_to('<img src="/assets/icons/edit.png" align="bottom" border="0" width="16" height="16" alt="edit" />'.html_safe, { controller: :glossary_terms, action: :edit, user_id: @glossary_client.id, id: table_row[0].id }, method: :get, remote: true)} #{h(table_row[0].txt)}</td>"
        res << "<td #{td_style}><i>#{pre_format(table_row[0].description)}</i></td>"
        @glossary_languages.each do |language|
          res << '<td ' + td_style + ' id="glossary_translation_%d_%s">' % [table_row[0].id, language.name]
          glossary_translation = table_row[1][language]
          if glossary_translation
            res << link_to('<img src="/assets/icons/edit.png" align="bottom" border="0" width="16" height="16" alt="edit" />'.html_safe, { controller: :glossary_terms, action: :edit_translation, user_id: @glossary_client.id, id: table_row[0].id, glossary_translation_id: glossary_translation.id, req: 'show' }, method: :post, remote: true)
            res << ' ' + pre_format(glossary_translation.txt)
          else
            res << link_to('<img src="/assets/icons/add.png" align="bottom" border="0" width="16" height="16" alt="add" />'.html_safe, { controller: :glossary_terms, action: :edit_translation, user_id: @glossary_client.id, id: table_row[0].id, language_id: language.id, req: 'new' }, method: :post, remote: true)
          end
          res << '</td>'
        end
        res << '</tr>'
      end
    end
    res << '</table>'
    res.join.html_safe

  end

  def highlight_glossary_terms(txt, glossary, client)
    if glossary && !glossary.empty?
      res = txt

      cnt = 0
      replace_dict = {}

      glossary.each do |k, glossary_entry|
        glossary_disp = nil
        dtoken = nil
        glossary_words = k.split

        # If the glosary is only one word...
        if glossary_words.count == 1
          res_words = res.downcase.split
          lidx = res_words.index k
          replaced_index = []

          while lidx
            word = res_words[lidx]
            res_words[lidx] = nil
            replaced_index << lidx
            unless replace_dict.key?(dtoken)
              glossary_disp = glossary_entry_display(glossary_entry)
              dtoken = "$$ICL_GE_#{cnt}$$"
              dtgt = link_to_remote(h(word), { url: { controller: :glossary_terms, action: :locate, user_id: client.id, id: glossary_entry[0] } }, title: glossary_disp, class: 'glossary_term')
              replace_dict[dtoken] = dtgt
              cnt += 1
            end
            lidx = res_words.index k
          end

          res = res.split
          replaced_index.each { |x| res[x] = dtoken }
          res = res.join(' ')
        else
          # If is multiple words search in the string.
          lidx = res.downcase.index(k)
          while lidx
            word = res[lidx...(lidx + k.length)]
            break if word.first == '$' # @ToDo must not allow replacement of tokens
            unless replace_dict.key?(dtoken)
              glossary_disp = glossary_entry_display(glossary_entry)
              dtoken = "$$ICL_GE_#{cnt}$$"
              dtgt = link_to_remote(h(word), { url: { controller: :glossary_terms, action: :locate, user_id: client.id, id: glossary_entry[0] } }, title: glossary_disp, class: 'glossary_term')
              replace_dict[dtoken] = dtgt
              cnt += 1
            end

            res = res[0...lidx] + dtoken + res[(lidx + k.length)..-1]
            lidx = res.downcase.index(k)
          end
        end
      end

      replace_dict.each do |k, v|
        res = res.gsub(k, v)
      end

      res
    else
      txt
    end
  end

  def glossary_entry_display(glossary_entry)
    res = []
    glossary_entry[1].each do |desc, lang|
      line = if !desc.blank?
               "_#{desc}_: "
             else
               ''
             end
      line += (lang.collect { |name, txt| "#{name} - *#{txt}*" }).join(', ')
      res << line
    end
    res.join('  ')
  end

  def user_switch
    # allow user switching
    res = ''
    if @orig_user
      res += link_to('Back to %s' % @orig_user.full_name, controller: '/login', action: :switch_user, id: @orig_user.id)
      res += '&nbsp; '
    end
    res.html_safe
  end

  def managed_work_controls(user, work, cost, as_button = true)
    if [ResourceLanguage, WebMessage, RevisionLanguage, WebsiteTranslationOffer].include?(work.class)
      content_tag(:div, class: 'managed_work_controls', id: "ManagedWorkFor#{work.class}#{work.id}") do
        managed_work_contents(user, work, cost, as_button)
      end
    end
  end

  def managed_work_contents(user, work, cost, as_button = true)
    is_website_translation_project =
      work.is_a?(WebsiteTranslationOffer) ||
      (work.class == RevisionLanguage && work.revision.cms_request_id.present?)

    content_tag(:div) do
      # first, determine the language pair
      from_lang = nil
      to_lang = nil
      can_edit = false
      client = nil
      if work.class == ResourceLanguage
        from_lang = work.text_resource.language
        to_lang = work.language
        client = work.text_resource.client
        project = work.text_resource
        can_edit = @user.has_client_privileges? && @user.can_modify?(project)
        can_enable_review = can_edit
        can_disable_review = can_edit
        enable_action = :update_status
        disable_action = :update_status
      elsif work.class == WebMessage
        from_lang = work.original_language
        to_lang = work.destination_language
        project = work
        can_edit = @user.has_client_privileges? && @user.can_modify?(project)
        can_enable_review = can_edit
        can_disable_review = can_edit
        enable_action = :update_status
        disable_action = :update_status
      elsif work.class == RevisionLanguage
        from_lang = work.revision.language
        to_lang = work.language
        client = work.revision.project.client
        project = work.revision.project
        can_enable_review = work.can_enable_review? && @user.can_modify?(work.revision)
        can_disable_review = work.revision.cms_request.try(:paid?) ? false : (work.can_disable_review? && @user.can_modify?(work.revision))
        enable_action = :enable
        disable_action = :disable
      elsif work.class == WebsiteTranslationOffer
        from_lang = work.from_language
        to_lang = work.to_language
        client = work.website.client
        project = work.website
        enable_action = :enable
        disable_action = :disable
      else
        return ''
      end

      if is_website_translation_project
        # Website translation projects have their own review controls at the
        # "Website" page (/wpml/websites/:id) and "Pending Translation Jobs"
        # page (/wpml/websites/:id/translation_jobs). No user should be able
        # to enable or disable review here.
        can_edit = false
        can_enable_review = false
        can_disable_review = false
      end

      is_client = [user, user.master_account].include?(client)

      # display the controls according to the status
      if work.managed_work
        stat = ''
        act = ''
        res = ''

        tooltip_text = _("Review is performed by a second translator who proofreads the translation quality and checks that it's free of any typos or errors. Review costs 50% extra per word and it's optional.")

        if work.managed_work.enabled?
          concat content_tag(:div, style: 'margin-bottom: 10px') {
            concat content_tag(:div, id: "review_status_#{work.id}") {
              if !work.managed_work.translator
                concat _('Review enabled')
              elsif [MANAGED_WORK_WAITING_FOR_PAYMENT, MANAGED_WORK_COMPLETE].include?(work.managed_work.translation_status)
                concat content_tag(:strong, work.managed_work.translator.full_name) + ' '.html_safe
                concat _('completed reviewing this project.')
              elsif work.managed_work.translation_status == MANAGED_WORK_REVIEWING
                concat content_tag(:strong, work.managed_work.translator.full_name) + ' '.html_safe
                concat _('is reviewing this project.')
              else
                concat content_tag(:strong, work.managed_work.translator.full_name) + ' '.html_safe
                concat _('will review this project.')
              end

              if @user.has_supporter_privileges? && work.managed_work.translator
                concat ' ('.html_safe
                concat link_to 'remove reviewer', remove_translator_managed_work_path(work.managed_work), method: :post
                concat ') '.html_safe
              end
            }

            # Do NOT display for Website Translation projects (WPML)
            if can_disable_review && !is_website_translation_project
              concat tooltip(tooltip_text + _(' You can disable it by pressing the disable review button.'))
              concat content_tag(:div, style: 'padding-top: 5px; float: right') {
                link_to(
                  _('Disable Review'),
                  { controller: :managed_works, action: disable_action, id: work.managed_work.id, active: MANAGED_WORK_INACTIVE, review_change_needs_refresh: 1 },
                  id: 'disable_review',
                  remote: true,
                  method: :post
                )
              }
            end
          }

        # Do NOT display for Website Translation projects (WPML)
        elsif can_enable_review && !is_website_translation_project
          concat content_tag(:div, style: 'margin-bottom: 7px') {
            concat _('Review disabled') + ' '.html_safe
            concat tooltip(tooltip_text + ' You can enable it by pressing the enable review button.' + "<p class='comment'>%s</p>" % _('Review costs 50% extra.'))

            link_text = cost && (cost > 0) ? (_('Enable Review') + ' (%.2f USD)' % cost) : _('Enable Review')
            if @user.has_supporter_privileges? && work.managed_work.translator
              concat _('Stored Reviewer: ') + ' '.html_safe
              concat content_tag(:strong, work.managed_work.translator.full_name)
              concat content_tag(:p) {
                concat ' ('.html_safe
                concat link_to('remove reviewer', remove_translator_managed_work_path(work.managed_work), method: :post)
                concat ') '.html_safe
              }
            end

            concat content_tag(:div, style: 'padding-top: 5px; float: right') {
              if as_button
                concat link_to_remote(
                  link_text,
                  { controller: :managed_works, action: enable_action, id: work.managed_work.id, active: MANAGED_WORK_ACTIVE, review_change_needs_refresh: 1 },
                  id: 'enable_review', class: 'rounded_but_orange', style: 'background-color: green; border: 1pt solid darkgreen',
                  method: :post
                )
              else
                concat link_to_remote(
                  link_text,
                  { controller: :managed_works, action: enable_action, id: work.managed_work.id, active: MANAGED_WORK_ACTIVE, review_change_needs_refresh: 1 },
                  id: 'enable_review',
                  method: :post
                )
              end
            }
          }
        else
          concat content_tag(:p, _('Review is disabled.'))
        end

        # Do NOT display for Website Translation projects (WPML)
        if @user.has_supporter_privileges? && work.managed_work.enabled? && !is_website_translation_project
          concat form_tag(set_translator_managed_work_path(work.managed_work)) {
            concat 'Nickname: '.html_safe
            concat text_field_tag :nickname
            concat '<br>'.html_safe
            concat submit_tag 'Assign reviewer', data: { disable_with: 'Assign reviewer' }
          }
        end
      else
        content_tag(:p, _('No reviewer selected.'))
      end
    end
  end

  def issues_for_object(object, potential_users)
    # Show table from own issues
    content_tag(:div) do
      unless object.issues.empty?
        header = @user.has_translator_privileges? ? _('Your issues for this string') : _('Existing issues')
        concat content_tag(:h4, header)
        concat content_tag(:table, cellspacing: 0, cellpadding: 3, class: 'stats', style: 'width: 100%') {
          concat content_tag(:tr, class: 'headerrow') {
            [_('Issue'), _('Kind')].each { |th| concat content_tag(:td, th) }
          }
          object.issues.sort_by(&:status).each do |issue|
            concat content_tag(:tr) {
              concat content_tag(:td, issue_title(issue))
              concat content_tag(:td, Issue::KIND_TEXT[issue.kind])
            }
          end
        }
        concat '<br />'.html_safe
      end

      # Show table from other issues to translators
      other_issues_warning = nil
      if @user.has_translator_privileges?
        if object.class == StringTranslation # && object.resource_string
          other_issues = object.resource_string.issues - object.issues
          unless other_issues.empty?
            other_issues_warning = _("Before you open new issues, please check if it's been reported already by other translators.")
            concat content_tag(:h4, _('Issues opened by others'))
            concat content_tag(:table, cellspacing: 0, cellpadding: 3, class: 'stats', style: 'width: 100%') {
              concat content_tag(:tr, class: 'headerrow') {
                [_('Issue'), _('Kind')].each { |th| concat content_tag(:td, th) }
              }
              other_issues.sort_by(&:status).each do |issue|
                concat content_tag(:tr) {
                  concat content_tag(:td, issue_title(issue, true))
                  concat content_tag(:td, Issue::KIND_TEXT[issue.kind])
                }
              end
            }
            concat '<br />'.html_safe
          end
        end
      end

      # make sure that there's someone to open the issue to
      unless potential_users.empty?
        users = {}
        idx = 1
        potential_users.each do |user, description|
          users["user#{idx}"] = user.id
          users["desc#{idx}"] = description
          idx += 1
        end
        concat content_tag(:div, other_issues_warning, class: 'errorExplanation') if other_issues_warning
        concat content_tag(:p) {
          link_to((_('Start a new issue') + ' &raquo;').html_safe,
                  {
                    controller: :issues,
                    action: :new,
                    object_type: object.class.to_s,
                    object_id: object.id
                  }.merge(users))
        }
      end
    end
  end

  def issue_title(issue, subscribe = false)
    params = {}
    params[:subscribe] = 1 if subscribe
    content_tag(:span) do
      if issue.status == ISSUE_OPEN
        concat image_tag('icons/flag.png', alt: 'issues', title: 'Open issue', style: 'float: right;')
        concat link_to(issue.title_with_emojis, { controller: :issues, action: :show, id: issue.id, key: issue.key }.merge(params))
      else
        concat link_to(issue.title_with_emojis, { controller: :issues, action: :show, id: issue.id, key: issue.key }.merge(params), class: 'completed_issue')
      end
    end
  end

  def issue_last_reply(issue)
    message = issue.messages.order('id DESC').first
    return '' unless message.present?

    link_to('%s, %s' % [message.user.try(:nickname), disp_time(message.chgtime)],
            { controller: :issues, action: :show, id: issue.id, key: issue.key, anchor: put_object_id(message) },
            title: message.body.gsub("\n", '  '))
  end

  def managed_work_link(managed_work, full_path = false)
    key = method(__method__).parameters.map { |arg| arg[1] }.map { |arg| "#{arg} = #{eval arg.to_s}" }.join(', ')
    Rails.cache.fetch("#{managed_work.cache_key}/managed_work_link-#{key}", expires_in: CACHE_DURATION) do
      url_args = full_path ? { escape: false, only_path: false, host: EMAIL_LINK_HOST, protocol: EMAIL_LINK_PROTOCOL } : {}
      work = managed_work.owner
      content_tag(:span) do
        if work.class == ResourceLanguage
          link_to({ controller: :text_resources, action: :show, id: work.text_resource.id }.merge(url_args)) do
            concat 'Software localization project - '
            concat content_tag(:b, work.text_resource.name); concat ' '.html_safe
            concat content_tag(:b, work.text_resource.language.name); concat ' '.html_safe
            concat content_tag(:b, work.language.name)
          end
        elsif work.class == WebMessage
          link_to("Instant translation ##{work.id}", { controller: :web_messages, action: :show, id: work.id }.merge(url_args))
        elsif work.class == RevisionLanguage
          link_to({ controller: :revisions, action: :show, id: work.revision.id, project_id: work.revision.project.id }.merge(url_args)) do
            concat 'Project - '
            concat content_tag(:b, work.revision.project.name); concat ' '.html_safe
            concat content_tag(:b, work.revision.language.name); concat ' '.html_safe
            concat content_tag(:b, work.language.name)
          end
        elsif work.class == WebsiteTranslationOffer
          link_to({ controller: :website_translation_offers, action: :review, website_id: work.website_id, id: work.id }.merge(url_args)) do
            concat 'CMS Website - '
            concat content_tag(:b, work.website.name); concat ' '.html_safe
            concat content_tag(:b, work.from_language.name); concat ' '.html_safe
            concat ' to '
            concat content_tag(:b, work.to_language.name)
          end
        end
      end
    end
  end

  def managed_work_review(managed_work)
    content_tag(:span) do
      work = managed_work.owner
      if work.class == ResourceLanguage
        link_to(controller: :text_resources, action: :show, id: work.text_resource.id) do
          concat 'Software localization project - '
          concat content_tag(:b, work.text_resource.name); concat ' '.html_safe
          concat content_tag(:b, work.text_resource.language.name); concat ' '.html_safe
          concat content_tag(:b, work.language.name)
        end
      elsif work.class == WebMessage
        link_to("Instant translation ##{work.id}", controller: :web_messages, action: :review, id: work.id)
      elsif work.class == RevisionLanguage
        title = content_tag(:div, class: 'm-t-5 clearfix', style: 'width: 50%') do
          concat 'Project - '
          concat content_tag(:b, work.revision.project.name); concat ' '.html_safe
          concat content_tag(:b, work.revision.language.name); concat ' '.html_safe
          concat content_tag(:b, work.language.name)
          concat link_to_translate(work.revision, 'btn-xs pull-right')
          concat content_tag(:div, '', class: 'clearfix')
        end
        if work.selected_bid
          chat = work.selected_bid.chat
          link_to(controller: :chats, action: :show, id: chat.id, revision_id: chat.revision.id, project_id: chat.revision.project.id) do
            title
          end
        else
          link_to(controller: :revisions, action: :show, id: work.revision.id, project_id: work.revision.project.id) do
            title
          end
        end
      elsif work.class == WebsiteTranslationOffer
        link_to(controller: :website_translation_offers, action: :show, website_id: work.website_id, id: work.id) do
          concat 'CMS Website - '
          concat content_tag(:b, work.website.name); concat ' '.html_safe
          concat content_tag(:b, work.from_language.name); concat ' '.html_safe
          concat content_tag(:b, work.to_language.name)
        end
      end
    end
  end

  def image_for_user(user, style = '')
    content_tag(:span) do
      if user.image
        concat image_tag(user.image.public_filename, size: user.image.image_size, alt: 'image', style: style)
      else
        concat image_tag('icons/login.png', width: 32, height: 32, alt: 'user', style: 'style')
      end
    end
  end

  def search_for_translators(from_lang, to_lang)
    url = { controller: :search, action: :by_language, source_lang_id: from_lang.id, target_lang_id: to_lang.id, go_back: 1 }
    if @user.has_supporter_privileges?
      url[:in_behalf_of] = controller_name.classify.constantize.find(params[:id]).client_id
    end
    content_tag(:div, class: 'all_translators') do
      if !@text_resource || (@text_resource && @user.can_modify?(@text_resource))
        concat link_to('Invite %s to %s translators' % [from_lang.name, to_lang.name], url, id: 'invite_translators', class: 'rounded_but_orange')
        concat tooltip("You can wait till translators apply or invite the ones you prefer. <br/><br/>Then please accept translator's application for each language, by clicking <b>Communicate with translator</b> And clicking on the button <b>Send strings to translator</b>")
      end
    end
  end

  def star_rating(translator)
    content_tag(:div, class: 'star-holder', style: 'margin: 5px auto') do
      concat content_tag(:div, '', class: 'star star-rating', style: "width: #{translator.rating}px;")
      (1..5).to_a.reverse.each do |x|
        concat content_tag(:div, image_tag('star.gif', alt: pluralize(2, 'star')), class: "star star#{x}")
      end
    end
  end

  def translator_profile(translator, actions_html, status_html = nil)
    content_tag(:div, class: 'translator_profile') do
      concat content_tag(:table) {
        concat content_tag(:tr) {
          concat content_tag(:td, class: 'translator_image') {
            concat content_tag(:div, style: 'text-align: center; margin: 4px 0;') {
              image_for_user(translator) + ' '.html_safe + star_rating(translator)
            }
            if @user.has_supporter_privileges? || (@user.has_client_privileges? && @user.can_modify?(@website))
              concat actions_html.html_safe
            end
          }
          concat content_tag(:td, class: 'translator_bio') {
            concat content_tag(:h3) {
              concat "#{translator.full_name}, #{translator.country.nname}".html_safe unless translator.country.blank?
              concat vacation_text(translator)
            }
            concat content_tag(:span, class: 'translator_info') {
              unless translator.jobs_in_progress.nil?
                concat content_tag(:acronym, _('Jobs in progress'), title: _('The number of translation projects this translator needs to complete'))
                concat ": #{translator.jobs_in_progress}"
                concat ' | '.html_safe
              end
              concat link_to(_('View profile'), controller: :users, action: :show, id: translator.id)
              concat ' | '.html_safe
              (concat status_html.html_safe; concat ' | '.html_safe) unless status_html.blank?
            }
            concat '<br /><br />'.html_safe
            concat content_tag(:p, pre_format(translator.bionote.i18n_txt(@locale_language)), style: 'padding-top:0; margin-top:0', class: 'quote') if translator.bionote && !translator.bionote.body.blank?
            unless translator.markings.empty?
              translator.markings.where('bookmarks.note != ?', '').order('bookmarks.id DESC').limit(3).each do |marking|
                concat content_tag(:p, style: 'margin-left: 20px') {
                  concat content_tag(:em, '&ldquo;'.html_safe + pre_format(marking.note) + '&rdquo;'.html_safe)
                  concat content_tag(:span, marking.user.full_name, style: 'margin-left: 1em; padding: 0 0.5em; background-color: #F0F0F0')
                }
              end
              if translator.markings.length > 3
                concat content_tag(:p, style: 'margin-left: 20px') {
                  link_to(_('%d more recommendation(s)') % (translator.markings.length - 3), controller: :users, action: :show, id: translator.id, anchor: 'bookmarks')
                }
              end

              if translator.cats.any?
                concat content_tag(:p, "Computer-Aided translation tools the translator knows to use: #{translator.cats.map(&:name).join(', ')}")
              end

              if translator.phones.any?
                concat content_tag(:p, "Phones that this translator have access to: #{translator.phones.map(&:name).join(', ')}")
              end
            end
          }
        }
      }
    end
  end

  def conditional_remote_link(condition, txt, url, method)
    condition ? link_to_remote(txt, url, remote: true, method: method) : txt
  end

  def item_translation_controls(item, languages, idx)
    return '' if !@auser || !@user || (@auser != @user)

    return '' if !languages || languages.empty? || !item

    translations = {}
    item.db_content_translations.each { |translation| translations[translation.language] = translation }

    content_tag(:div) do
      concat content_tag(:p) {
        languages.each do |language|
          label = if translations.key?(language)
                    '%s (edit)' % language.name
                  else
                    content_tag(:span, language.name)
                  end
          concat link_to_remote(label, controller: :db_content_translations, action: :edit, req: :show, obj_class: item.class.to_s, obj_id: item.id, edit_box: idx, language_id: language.id) + ' | '
        end
      }
      concat content_tag(:div, '', id: "db_translation_#{idx}")
    end
  end

  def locale_footer
    unless DISABLE_INTERNALIZATION
      return if session[:hide_locale_bar]

      LOCALES_FOOTER.collect do |loc|
        locale_name = loc[0]
        locale_code = loc[1]

        # Prevents "incompatible character encodings: ASCII-8BIT and UTF-8" error in minitest. spetrunin 10/28/2016
        locale_name = locale_code if Rails.env.test?

        if session[:loc_code] == locale_code
          locale_name
        else
          link_to(locale_name, { controller: :login, action: :change_locale, loc_code: locale_code }, remote: true)
        end
      end.join(' &nbsp; | &nbsp; ').html_safe
    end
  end

  def present_date(date)
    [Date, Time, DateTime].include?(date.class) ? date.strftime('%b/%d/%Y') : date
  end

  def cms_request_translations(cms_request)
    content_tag(:span) do
      cms_request.cms_target_languages.each_with_index do |ctl, idx|
        next unless ctl.permlink
        concat link_to(ctl.language.name, ctl.permlink)
        concat ' &raquo;'.html_safe
        concat ' | '.html_safe unless ctl == cms_request.cms_target_languages[idx]
      end
    end
  end

  def projects_text_to_aliases(alias_profile)
    if alias_profile.project_access_mode == AliasProfile::ALL_PROJECTS
      permissions = []
      permissions << 'create' if alias_profile.project_create
      permissions << 'view' if alias_profile.project_view
      permissions << 'modify' if alias_profile.project_modify

      unless permissions.empty?
        return 'Can ' + permissions.join(', ').gsub(/(.*)(,)(.*)/, '\1, and\3') + ' all projects'
      end
    elsif alias_profile.project_access_mode == AliasProfile::PROJECTS_LIST
      unless alias_profile.all_projects_list.empty?
        project_names = Project.find(alias_profile.project_list).map { |x| '<b>' + x.name + '</b>' }
        project_names += Website.find(alias_profile.website_list).map { |x| '<b>' + x.name + '</b>' }
        project_names += TextResource.find(alias_profile.text_resource_list).map { |x| '<b>' + x.name + '</b>' }
        project_names += WebMessage.find(alias_profile.web_message_list).map { |x| '<b>' + x.name + '</b>' }

        return 'Have access to the projects ' + project_names.join(', ').gsub(/(.*)(,)(.*)/, '\1, and\3')
      end
    end
    "Can't access projects"
  end

  def financials_text_to_aliases(alias_profile)
    permissions = []
    permissions << 'view history' if alias_profile.financial_view
    permissions << 'make deposits' if alias_profile.financial_deposit
    permissions << 'make payments' if alias_profile.financial_pay

    if permissions.empty?
      "Doesn't have any financial access"
    else
      'Can ' + permissions.join(', ').gsub(/(.*)(,)(.*)/, '\1, and\3')
    end
  end

  def to_dollars(n)
    '%.2f USD' % n
  end

  # Format numbers as currency (USD). Round instead of cutting extra decimal
  # digits to prevent revenue loss. After rounding, must ensure the number of
  # decimal places is always the same (add trailing zeros if necessary)
  def rounded_dollars(amount, decimal_places = 2)
    rounded_amount = amount.round(decimal_places)
    padded_amount = sprintf("%.#{decimal_places}f", rounded_amount)
    "$#{padded_amount} USD"
  end

  def revision_path(revision)
    project_revision_path(revision.project, revision)
  end

  def revision_url(revision)
    project_revision_url(revision.project, revision)
  end

  def generic_project_url(project)
    case project
    when Revision then
      project_revision_url(project.project, project)
    when TextResource then
      text_resource_url(project)
    when Website then
      wpml_website_url(project)
    end
  end

  def user_projects_options(opts = {})
    options = []
    options << ['Not related to a project', '0']
    if @user.revisions.any?
      options << ['-- Bidding projects --', -1]
      options += @user.revisions.map { |x| [x.project.name, "Revision-#{x.id}"] }
    end
    text_resources = @user.is_a?(Translator) ? @user.assigned_text_resources : @user.text_resources
    if text_resources.any?
      options << ['-- Software projects --', -1]
      options += text_resources.map { |x| [x.name, "TextResource-#{x.id}"] }
    end
    if defined?(@user.websites) && @user.websites.any?
      options << ['-- CMS projects--', -1]
      options += @user.websites.map { |x| [x.name, "Website-#{x.id}"] }
    end
    if @user.web_messages.any?
      options << ['-- Instant Translation Projects--', -1]
      options += @user.web_messages.map { |x| [x.name || 'No title', "WebMessage-#{x.id}"] }
    end

    disabled = [-1]
    options_for_select(options, opts.merge!(disabled: disabled))
  end

  def date_picker_field(object_name, method, options = {}, extra_html = nil)
    value = options[:value]
    display_value = value.respond_to?(:strftime) ? value.strftime('%b %d, %Y') : ''
    display_value << '[ choose date ]' if display_value.blank?
    display_value << extra_html if extra_html
    options.delete('value')
    content_tag(:span) do
      concat link_to(display_value.html_safe, 'javascript:void(0)', id: "_#{object_name}_link", class: '_date_picker_link', onclick: "DatePicker.toggleDatePicker('#{object_name}'); return false;")
      concat hidden_field_tag(object_name, value, method: method)
      concat content_tag('div', nil, class: 'date_picker', style: 'display: none', id: "_#{object_name}_calendar")
    end
  end

  # TODO: temporary fallback. update places where it is used. spetrunin 10/24/2016
  def link_to_remote(body, url_options = {}, html_options = {})
    html_options[:remote] = true
    link_to body, url_options, html_options
  end

  def link_to_function(title, javascript)
    "<a href=\"#\" onclick=\"#{javascript}; return false;\">#{title}</a>"
  end

  def create_error_messages(object, header)
    if object.errors.any?
      content_tag :div, id: 'errorExplanation', class: 'errorExplanation' do
        content_tag(:h2, header) +
          content_tag(:p, 'There were problems with the following:') +
          content_tag(:ul) do
            object.errors.each do |name, msg|
              concat(content_tag(:li, "#{name.to_s.tr('_', ' ').titleize}: #{msg}"))
            end
          end
      end
    end
  end

  def money_field_tag_for(form, attr, extra_callback = '')
    form.number_field attr, size: MONEY_FIELD, min: 0, step: '0.01', maxlength: MONEY_FIELD, oninput: 'javascript: validate_money_field(this);' + extra_callback
  end

  def money_field_tag(attr, value, extra_callback = '')
    number_field_tag attr, value, size: MONEY_FIELD, min: 0, step: '0.01', maxlength: MONEY_FIELD, oninput: 'javascript: validate_money_field(this);' + extra_callback
  end

  def id_field_tag(attr, value)
    number_field_tag attr, value, size: ID_FIELD, min: 0, maxlength: ID_FIELD, oninput: 'javascript: validate_money_field(this);'
  end

  def markdown(text)
    markdown = Redcarpet::Markdown.new(Redcarpet::Render::HTML.new(filter_html: true, hard_wrap: true), extensions = {})
    markdown.render(text)
  end

  def link_to_translate(revision, btn_class = '')
    content_tag(:span) do
      concat content_tag(:span, class: 'pull-left m-r-5') {
        link_to_translate_btn(revision, btn_class)
      }
      if ENABLE_MACHINE_TRANSLATION
        concat content_tag(:span) {
          mt_switch(revision)
        }
      end
      concat content_tag(:span, '', style: 'clear:both')
    end
  end

  def link_to_translate_btn(revision, btn_class = '')
    return '' unless @user.is_a?(Translator) && @user.webta_enabled?
    cms_request = @user.translatable_cms revision
    type = @user.is_reviewer_of?(revision) ? 'review' : 'translate'
    if cms_request
      link_to(@user.link_to_webta(cms_request, type), target: :blank, class: "btn btn-primary #{btn_class}") do
        concat image_tag('icons/webta.ico', size: '16x16', title: 'Open', style: 'margin-bottom: -3px; margin-right: 5px'); concat type.capitalize.html_safe
      end
    else
      ''
    end
  end

  def mt_switch(revision)
    return '' unless @user.is_a?(Translator) && @user.webta_enabled?
    cms_request = @user.translatable_cms revision
    return '' unless cms_request.present?
    form_tag({
               controller: :cms_requests,
               action: :toggle_tmt_config,
               website_id: cms_request.website.id,
               id: cms_request.id
             },
             class: "mt-switch-form-#{cms_request.id}",
             remote: true,
             data: {
               confirm: !cms_request.get_current_translators_tmt_config.enabled ? 'I understand the risk, enable MT' : nil
             }) do
      is_enabled = cms_request.get_current_translators_tmt_config.enabled
      content_tag(:label, class: "switch pull-left m-r-5 mt-switch #{is_enabled ? 'mt-enabled' : 'mt-disabled'}") do
        concat check_box_tag :tmt_enabled, 'enabled', is_enabled, onchange: 'jQuery(this.form).submit()'
        concat content_tag :span, '', class: 'slider'
        concat content_tag :span, 'Yes', class: 'switch-on'
        concat content_tag :span, 'No', class: 'switch-off'
      end
    end
  end

  def link_to_translate_practice_project
    return '' unless @user.is_a?(Translator) && @user.webta_enabled?
    cms_request = CmsRequestFake.new(@user)
    btn_text = ' Open test project'

    content_tag :div do
      link_to(@user.link_to_webta(cms_request), target: :blank, class: "btn btn-primary #{btnClass}") do
        concat image_tag('icons/webta.ico', size: '16x16', title: 'Open', style: 'margin-bottom: -3px;'); concat btn_text.html_safe
      end
    end
  end

  def seconds_to_pretty_time(seconds)
    mm, ss = seconds.divmod(60)
    hh, mm = mm.divmod(60)
    dd, hh = hh.divmod(24)
    [dd, hh, mm, ss] # returns days, hours, minutes, seconds

    [].tap do |str|
      str << pluralize(dd, 'day') if dd != 0
      str << pluralize(hh, 'hr')
      str << pluralize(mm, 'min')
    end.join(' ')
  end

  def auto_assignment_time_elapsed(assigned_at)
    content_tag(:span, seconds_to_pretty_time(Time.now - assigned_at), style: 'display:block') if assigned_at.present?
  end

  private :create_error_messages
end
