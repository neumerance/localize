module WebsitesHelper
  def unfunded_requests(unfunded_cms_requests)
    total = 0
    infotab_header([_('Job ID'), _('Created'), _('Document'), _('Words to translate'), _('Translation cost')]) do |res|
      unfunded_cms_requests.each do |unfunded_cms_request|
        cms_request = unfunded_cms_request
        cost = unfunded_cms_request.calculate_required_balance(unfunded_cms_request.cms_target_languages, nil).first
        res << '<tr><td>' + link_to(cms_request.id, controller: :cms_requests, action: :show, website_id: cms_request.website_id, id: cms_request.id) + '</td>'
        res << "<td>#{disp_date(cms_request.created_at)}</td>"
        res << '<td>' + link_to(cms_request.title, controller: :cms_requests, action: :show, website_id: cms_request.website_id, id: cms_request.id) + '</td>'
        res << '<td><ul>'
        cms_request.cms_target_languages.each do |cms_target_language|
          res << '<li>' + cms_target_language.language.nname + ': ' + cms_target_language.word_count.to_s + '</li>'
        end
        res << '</ul></td>'
        res << '<td>' + _('%.2f USD') % cost + '</td>'
        res << '</tr>'
        total += cost
      end
      res << '<tr><th colspan="4"><b>' + _('Subtotal') + '</b></th><th><b>' + _('%.2f USD') % total + '</b></th></tr>'
      res << '<tr><th colspan="4"><b>' + _('Current in your account') + '</b></th><th><b>' + _('%.2f USD') % @website.client.money_account.balance + '</b></th></tr>'
      missing_funds = total - @website.client.money_account.balance
      res << '<tr><th colspan="4"><b>' + _('Missing funds') + '</b></th><th><b>' + _('%.2f USD') % missing_funds + '</b></th></tr>'
      res << '</table>'
      res
    end
  end

  def applications_for_offer(website_translation_offer)
    if website_translation_offer.sent_notifications.empty?
      res = _('Translators were not notified yet.')
    else
      res = _('%s translator(s) were notified about this project.') % website_translation_offer.sent_notifications.length
      if (@user.has_supporter_privileges? || ([@user, @user.master_account].include?(website_translation_offer.website.client) && @user.can_modify?(website_translation_offer.website))) && (website_translation_offer.status == TRANSLATION_OFFER_OPEN)
        res += '<br />' + button_to(_('Resend notifications'), { controller: :website_translation_offers, action: :resend_notifications, website_id: website_translation_offer.website_id, id: website_translation_offer.id }, 'data-confirm' => 'Are you sure you want to notify translators again? Please use this only if the project setting has changed.')
      end
    end
    res.html_safe
  end

  def project_status_for_xml
    res = []
    res << ['icl_status_jobs', _('Jobs sent to ICanLocalize: %d - %s') % [@website.cms_requests.length, link_to(_('view jobs'), only_path: false, controller: :cms_requests, action: :index, website_id: @website.id, accesskey: @website.accesskey, compact: 1)]]
    if @balance
      res << if @planned_expenses && (@planned_expenses > 0)
               ['icl_status_balance', _('Your balance at ICanLocalize is %.2f USD. Planned expenses: %.2f USD. Available balance: %.2f USD. Visit your %s page to make a new deposit.') % [@account_total, @planned_expenses, @balance, link_to(_('ICanLocalize finance'), only_path: false, controller: :finance, action: :index, wid: @website.id, accesskey: @website.accesskey, compact: 1)]]
             else
               ['icl_status_balance', _('Your balance at ICanLocalize is %.2f USD. Visit your %s page to make a new deposit.') % [@balance, link_to(_('ICanLocalize finance'), only_path: false, controller: :finance, action: :index, wid: @website.id, accesskey: @website.accesskey, compact: 1)]]
             end
    end
    if @unfunded_requests && !@unfunded_requests.empty?
      res << ['icl_status_balance', _('%d jobs cannot begin due to low funding.') % @unfunded_requests.length]
    end
    res << ['icl_status_help', _('For any help with this project, visit the %s') % link_to(_('support center'), only_path: false, controller: :support, action: :index, wid: @website.id, accesskey: @website.accesskey, compact: 1)]
    (res.collect { |r| ('<p%s>%s</p>' % [r[0] ? " class=\"#{r[0]}\"" : '', r[1]]).gsub('<', '&lt;').gsub('>', '&gt;') }).join
  end

  def translators_management_info_for_xml(plain = false)
    # this will display open offers or translators who are invited and didn't respond
    offers =
      @website.website_translation_offers.
      joins(:website_translation_contracts).
      where('(website_translation_offers.status = ?) OR (website_translation_contracts.status NOT IN (?))', TRANSLATION_OFFER_OPEN, [TRANSLATION_CONTRACT_ACCEPTED, TRANSLATION_CONTRACT_DECLINED])

    res = []
    offers.each do |offer|
      lang_stat = []
      lang_stat << link_to(_('%s to %s translators') % [offer.from_language.nname, offer.to_language.nname], only_path: false, controller: :website_translation_offers, action: :show, website_id: @website.id, id: offer.id, accesskey: @website.accesskey, compact: 1)
      lang_stat << (offer.status == TRANSLATION_OFFER_OPEN ? _('open for translators to apply') : _('only invited translators can apply'))
      open_applications = offer.website_translation_contracts.where('website_translation_contracts.status NOT IN (?)', [TRANSLATION_CONTRACT_ACCEPTED, TRANSLATION_CONTRACT_DECLINED])
      unless open_applications.empty?
        lang_stat << link_to(_('%d translators applied or invited') % open_applications.length, only_path: false, controller: :website_translation_offers, action: :show, website_id: @website.id, id: offer.id, accesskey: @website.accesskey, disp_mode: DISPLAY_APPLIED_TRANSLATORS, compact: 1)
      end
      res << lang_stat.join(' | ')
    end

    if plain
      (res.collect { |line| ('<p>%s</p>' % line) }).join
    else
      (res.collect { |line| ('<p>%s</p>' % line).gsub('<', '&lt;').gsub('>', '&gt;') }).join
    end
  end

  def languages_custom_text
    offers =
      @website.website_translation_offers.joins(:website_translation_contracts).where(
        '(website_translation_offers.status = ?) OR
         (website_translation_contracts.status NOT IN (?))',
        TRANSLATION_OFFER_OPEN, [TRANSLATION_CONTRACT_ACCEPTED, TRANSLATION_CONTRACT_DECLINED]
      )

    texts = []
    offers.each do |offer|
      format_string = if offer.status == TRANSLATION_OFFER_OPEN
                        "%s | #{_('open for translators to apply')}"
                      else
                        "%s | #{_('only invited translators can apply')}"
                      end

      open_applications = offer.website_translation_contracts.where('website_translation_contracts.status NOT IN (?)', [TRANSLATION_CONTRACT_ACCEPTED, TRANSLATION_CONTRACT_DECLINED])
      unless open_applications.empty?
        format_string += ' | %s'
        extra_link = {
          text: _('%d translators applied or invited') % open_applications.length,
          url: url_for(only_path: false, controller: :website_translation_offers, action: :show,
                       website_id: @website.id, id: offer.id, accesskey: @website.accesskey,
                       disp_mode: DISPLAY_APPLIED_TRANSLATORS, compact: 1)
        }
      end

      texts << {
        format_string: format_string,
        links: [
          {
            text: _('%s to %s translators') % [offer.from_language.nname, offer.to_language.nname],
            url: url_for(only_path: false, controller: :website_translation_offers, action: :show, website_id: @website.id, id: offer.id, accesskey: @website.accesskey, compact: 1)
          }
        ]
      }
      texts.last[:links] << extra_link if extra_link
    end

    texts.to_json
  end

  def string_translation_custom_text
    texts = []

    texts << {
      format_string: ('Your balance with ICanLocalize is %s. Visit your %%s page to deposit additional funds' % @website.client.money_account.balance),
      links: {
        text: 'ICanLocalize finance',
        url: "https://www.icanlocalize.com/finance?wid=#{@website.id}8&compact=1&accesskey=#{@website.accesskey}"
      }
    }

    texts.to_json
  end

  def reminders_custom_text
    texts = []

    @reminders.each do |reminder|
      format_string = reminder.print_details(@website.client) + '   (%s)'
      links = []
      links << { text: 'view', url: url_for(reminder.link_to_handle(@website.client).merge(only_path: false)) }

      if reminder.user_can_delete
        format_string += ' - (%s)'
        links << { text: 'dismiss', url: url_for(controller: 'reminders', action: 'destroy', wid: @website.id, accesskey: @website.accesskey, id: reminder.id, only_path: false), dismiss: true }
      end

      texts << { format_string: format_string, links: links }
    end

    if @missing_amount > 0
      links = [
        {
          text: 'view',
          url: url_for(only_path: false, controller: '/wpml/translation_jobs', action: :show, id: @website.id, accesskey: @website.accesskey, compact: 1)
        }
      ]
      texts << {
        format_string: "You don't have enough funds in your ICanLocalize account - [b]Funds required - $%s[/b] (%%s)" % @missing_amount,
        links: links
      }
    end

    texts.to_json
  end

  def balance_custom_text
    texts = []
    texts << {
      format_string: _('Jobs sent to ICanLocalize: %d - %%s') % @website.cms_requests.length,
      links: [
        {
          text: _('view jobs'),
          url: url_for(only_path: false, controller: :cms_requests, action: :index, website_id: @website.id, accesskey: @website.accesskey, compact: 1)
        }
      ]
    }

    payable_cms_requests_count = @website.payable_cms_requests.size

    if payable_cms_requests_count > 0
      links = [
        {
          text: 'Click here to pay',
          url: wpml_website_translation_jobs_url(@website, accesskey: @website.accesskey, compact: 1)
        }
      ]
      texts << {
        format_string: '[b]You have %s unpaid translation jobs. Translations will only start after payment is received[/b]. %%s.' % payable_cms_requests_count,
        links: links
      }
    end

    texts << {
      format_string: _('For any help with this project, visit the %s'),
      links: [
        {
          text: _('support center'),
          url: url_for(only_path: false, controller: :support, action: :index, wid: @website.id, accesskey: @website.accesskey, compact: 1)
        }
      ]
    }
    texts.to_json
  end

end
