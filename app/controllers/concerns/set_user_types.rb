module SetUserTypes
  def set_utypes
    @utype = params[:utype]
    client_user_agreement = '<a target="_blank" href="http://docs.icanlocalize.com/?page_id=153"><b>' + _('User Agreement for clients') + '</b></a> ' + _('(opens in a new window)')
    translator_user_agreement = '<a target="_blank" href="http://docs.icanlocalize.com/?page_id=155"><b>' + _('User Agreement for translators') + '</b></a> ' + _('(opens in a new window)')
    @utypes = [[_('Website owner'), 'Client', "document.getElementsByName('accept_agreement')[0].disabled = false; document.getElementsByName('accept_agreement')[0].checked = false; document.getElementById('agreement').innerHTML = '#{client_user_agreement}'; document.getElementsByName('submit')[0].disabled = true;"],
               [_('Translator'), 'Translator', "document.getElementsByName('accept_agreement')[0].disabled = false; document.getElementsByName('accept_agreement')[0].checked = false; document.getElementById('agreement').innerHTML = '#{translator_user_agreement}'; document.getElementsByName('submit')[0].disabled = true;"]]

    if @utype == 'Client'
      @default_user_agreement = client_user_agreement
      @disable_user_agreement = 'false'
    elsif @utype == 'Translator'
      @default_user_agreement = translator_user_agreement
      @disable_user_agreement = 'false'
    else
      @default_user_agreement = 'User Agreement <span class="warning">(select user type above before accepting the agreement)</span>'.html_safe
      @disable_user_agreement = 'true'
    end
  end
end
