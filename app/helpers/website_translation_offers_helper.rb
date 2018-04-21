module WebsiteTranslationOffersHelper
  def contract_status(website_translation_contract, user)
    res = WebsiteTranslationContract::TRANSLATION_CONTRACT_DESCRIPTION[website_translation_contract.status]
    new_messages = website_translation_contract.new_messages(user).length
    if new_messages > 0
      res += '<br /><b>' + _('%d new messages') % new_messages + '</b>'
    end
    res
  end

  def status_controls(translator, contract, min_bid = nil, max_bid = nil)
    res = ''
    if !@website_translation_offer.translator_can_apply(translator)
      res = _('This is the reviewer')
    elsif !contract
      res += '<div style="clear: both; margin-top: 10px;"></div>'
      res += link_to(_('Invite'), { action: :new_invitation, translator_id: translator.id, but: _('Invite %s') % translator.full_name }, class: 'rounded_but_orange')
      res += '<div style="clear: both; margin-top: 10px;"></div>'
    else
      operation = nil

      icon = nil
      if contract.status == TRANSLATION_CONTRACT_NOT_REQUESTED
        status_txt = contract.invited == 1 ? _('Not yet responded to invitation') : _('Not applied')
        icon = contract.invited == 1 ? 'RO-Mx1-24_circle-help-3.png' : nil
      elsif contract.status == TRANSLATION_CONTRACT_REQUESTED
        status_txt = _('Interested')
        icon = 'RO-Mx1-24_hand-open.png'
        operation = [_('Accept Application'), TRANSLATION_CONTRACT_ACCEPTED]
      elsif contract.status == TRANSLATION_CONTRACT_ACCEPTED
        status_txt = _('Application Accepted')
        icon = 'RO-Mx1-24_checkmark-green.png'
        operation = [_('Cancel Acceptance'), TRANSLATION_CONTRACT_DECLINED]
      elsif contract.status == TRANSLATION_CONTRACT_DECLINED
        status_txt = _('Application Declined')
        icon = 'RO-Mx1-24_circle-red-cancel.png'
        operation = [_('Accept Application'), TRANSLATION_CONTRACT_ACCEPTED]
      end
      res += '<div style="margin-bottom: 2px;">'
      if icon
        res += '<img src="/assets/icons/%s" width="24" height="24" alt="" class="invitation_status" />' % icon
      end
      res += '<span class="comment">' + status_txt + '<br />'
      if contract.amount && (contract.amount > 0) && [TRANSLATION_CONTRACT_ACCEPTED, TRANSLATION_CONTRACT_DECLINED, TRANSLATION_CONTRACT_REQUESTED].include?(contract.status)
        res += '%.2f USD/word<br />' % contract.amount
      end
      res += link_to(_('Chat'), controller: :website_translation_contracts, action: :show, website_id: @website.id, website_translation_offer_id: @website_translation_offer.id, id: contract.id)
      res += '</span>'
      res += '</div>'
      confirmation_message = _('Are you sure?')
      if operation.present?
        confirmation_message = bid_acceptance_confirmation_message(contract, min_bid, max_bid, confirmation_message) if operation[1] == TRANSLATION_CONTRACT_ACCEPTED
        res += button_to(operation[0], { controller: :website_translation_contracts, action: :update_application_status, website_id: @website.id, website_translation_offer_id: @website_translation_offer.id, id: contract.id, status: operation[1], return_to_src: 1 }, 'data-confirm' => confirmation_message)
      end
    end
    res
  end

  def bid_acceptance_confirmation_message(contract, min_bid = 0, max_bid = 0, default_msg = '')
    msg = default_msg
    if min_bid.present? || max_bid.present?
      if contract.amount.to_f != min_bid || contract.amount.to_f != max_bid
        msg = "You already accepted a different translator for #{@website_translation_offer.from_language.name.titleize} to #{@website_translation_offer.to_language.name.titleize} at a rate of $#{'%.2f USD/word' % (max_bid ? max_bid : min_bid)}. "\
              "This translator is asking for a different rate ($#{'%.2f USD/word' % contract.amount})."\
              "\n\n"\
              'If you accept this bid, you will not know how much you are paying, as each of the translators will be able to take jobs that you send.'
      end
    end
    msg
  end

  def infos_controls(translator, contract)
    if contract
      label = (_('Chat with %s') % translator.full_name)
      new_messages = contract.new_messages(@user).length
      label = content_tag(:strong, _('%d new messages') % new_messages) if new_messages > 0
      link_to(label, controller: :website_translation_contracts, action: :show, website_id: @website.id, website_translation_offer_id: @website_translation_offer.id, id: contract.id)
    end
  end

  def display_mode_line(disp_mode)
    content_tag(:span) do
      src = []

      # If there are any translators for that language pair that specialize
      # in the website's subject, display the "translators specializing in..."
      # filter option.
      any_specialized_translators = @website.category && Translator.find_by_languages(
        USER_STATUS_QUALIFIED,
        @website_translation_offer.from_language_id,
        @website_translation_offer.to_language_id,
        "AND (translator_categories.category_id=#{@website.category_id})"
      ).any?

      if any_specialized_translators
        src << [DISPLAY_TRANSLATORS_IN_CATEGORY, _('%s to %s translators specializing in %s') % [@website_translation_offer.from_language.nname, @website_translation_offer.to_language.nname, @website.category.nname]]
      end

      src += [[DISPLAY_ALL_TRANSLATORS, _('All %s to %s translators') % [@website_translation_offer.from_language.nname, @website_translation_offer.to_language.nname]],
              [DISPLAY_INVITED_TRANSLATORS, _('Translators you invited')],
              [DISPLAY_ACCEPTED_TRANSLATORS, _('Translator you selected')],
              [DISPLAY_APPLIED_TRANSLATORS, _('Translators who applied')]]

      src.each do |mode_pair|
        concat link_to_if(disp_mode != mode_pair[0], mode_pair[1], action: :show, id: @website_translation_offer.id, disp_mode: mode_pair[0])
        concat ' &nbsp; | &nbsp; '.html_safe unless mode_pair == src.last
      end
    end
  end
end
