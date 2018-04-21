module FinanceHelper
  include MoneyTransactionsHelper

  def money_transaction_details(account_line, money_transaction)
    content_tag(:div){
      url = nil
      res = nil
      details = []
      # is a withdraw (payment to translator) from escrow -> to translator
      if money_transaction.source_account == account_line.account
        paid_to = money_transaction.target_account
        if paid_to
          if paid_to.class == BidAccount
            if paid_to.bid
              res = content_tag(:span, _('Escrow deposit for translation of %s (%s revision) to %s')%[paid_to.bid.chat.revision.project.name, paid_to.bid.chat.revision.name, paid_to.bid.revision_language.language.nname])
              url = url_for(:controller=>:bids, :action=>:show, :project_id=>paid_to.bid.chat.revision.project_id, :revision_id=>paid_to.bid.chat.revision_id, :chat_id=>paid_to.bid.chat_id, :id=>paid_to.bid)
              details << [_('Project name'),paid_to.bid.chat.revision.project.name]
              details << [_('Full description'),paid_to.bid.chat.revision.description]
            else
              res = content_tag(:span, _('Escrow to canceled bid'))
            end
          elsif paid_to.class == ExternalAccount
            if money_transaction.operation_code == TRANSFER_GENERAL_REFUND
              res = content_tag(:span, _('Refund from %s order %s') % [ExternalAccount::NAME[paid_to.external_account_type], money_transaction.owner.txn ])
            else
              res = content_tag(:span, _('Withdrawal to %s account - %s')%[ExternalAccount::NAME[paid_to.external_account_type], paid_to.identifier])
            end
            if money_transaction.owner.class == Invoice
              url = url_for(:action=>:invoice, :id=>money_transaction.owner.id)
            elsif money_transaction.owner.class == MassPaymentReceipt
              url = url_for(:action=>:mass_payment_receipt, :id=>money_transaction.owner.id)
            end
          elsif money_transaction.operation_code == TRANSFER_PAYMENT_FOR_INSTANT_TRANSLATION
            res = content_tag(:span,  _('Instant text translation from %s to %s')%[money_transaction.owner.original_language.nname,money_transaction.owner.destination_language.nname])
            url = url_for(:controller=>:web_messages, :action=>:show, :id=>money_transaction.owner)
            details << [_('Text'),money_transaction.owner.get_name]
          elsif (money_transaction.operation_code == TRANSFER_DEPOSIT_TO_RESOURCE_TRANSLATION) &&
              money_transaction.owner && (money_transaction.owner.class == ResourceLanguage)
            res = content_tag(:span, _('Software localization from %s to %s')%[money_transaction.owner.text_resource.language.nname,money_transaction.owner.language.nname])
            url = url_for(:controller=>:text_resources, :action=>:show, :id=>money_transaction.owner.text_resource.id)
            details << [_('Project name'),money_transaction.owner.text_resource.name]
            # details << [_('Full description'),money_transaction.owner.text_resource.description]
          elsif (paid_to.class == ResourceLanguageAccount)
            if money_transaction.owner && paid_to.resource_language && paid_to.resource_language.text_resource
              res = content_tag(:span, _('Software localization from %s to %s')%[paid_to.resource_language.text_resource.language.nname,paid_to.resource_language.language.nname])
              url = url_for(:controller=>:text_resources, :action=>:show, :id=>paid_to.resource_language.text_resource.id)
              details << [_('Project name'), paid_to.resource_language.text_resource.name]
              details << [_('Full description'),paid_to.resource_language.text_resource.description]
            else
              res = content_tag(:span, _('Payment for deleted software localization project'))
            end
          elsif (paid_to.class == KeywordAccount)
            if paid_to.keyword_project
              if paid_to.keyword_project.owner
                project = link_to(paid_to.keyword_project.owner.project_name, generic_project_url(paid_to.keyword_project.owner.project))
                language = paid_to.keyword_project.owner.language.name
              else
                project = "Deleted project"
                language = "unknown"
              end

              number = paid_to.keyword_project.keyword_package.keywords_number
              res = (_("Payment for keyword package of %s words on project %s to language %s<br>") % [number, project, language]).html_safe
            end
          elsif (paid_to.class == TaxAccount)
            if money_transaction.owner.class == Invoice
              res = content_tag(:span, _("VAT Tax withdraw In %s (%s%%)") % [Country.find(money_transaction.owner.tax_country_id).name, money_transaction.owner.tax_rate])
            else
              res = content_tag(:span, _('VAT Tax withdraw'))
            end
          elsif paid_to.is_a? UserAccount
            # Software Project
            if money_transaction.owner_type == 'StringTranslation'
              if money_transaction.owner.resource_string
                if money_transaction.operation_code == TRANSFER_PAYMENT_FROM_RESOURCE_TRANSLATION
                  for_what = (_('String <b>Translation</b> from %s to %s' % [money_transaction.owner.resource_string.text_resource.language.nname,money_transaction.owner.language.nname])).html_safe
                else
                  for_what = (_('String <b>Review</b> from %s to %s' % [money_transaction.owner.resource_string.text_resource.language.nname,money_transaction.owner.language.nname])).html_safe
                end
                url = url_for(:controller=>:resource_strings, :action=>:show, :text_resource_id=>money_transaction.owner.resource_string.text_resource, :id=>money_transaction.owner.resource_string)
                res = link_to(for_what, url)
                res << "<br/><b>#{_('Paid to:')}</b> #{paid_to.user.nickname} ".html_safe
                res << link_to('Money Account', {:controller => :finance, :action => :account_history, :id=> paid_to.user.money_account.id})
                res << "<br/><b>#{_('String:')}</b> #{money_transaction.owner.resource_string.id} ".html_safe
                res << "<b>#{_('Label:')}</b> #{money_transaction.owner.resource_string.token}".html_safe
              else
                res = content_tag(:span, "Deleted resource translation #{money_transaction.owner_id}")
              end

            elsif money_transaction.operation_code == TRANSFER_PAYMENT_FROM_RESOURCE_TRANSLATION
              res = content_tag(:span, _("Translation Payment to: "))
              res << user_link(money_transaction.target_account.user)
            else
              res = content_tag(:span, _("Transfer to account: "))
              res += user_link(money_transaction.target_account.user)
            end
          else
            res = content_tag(:span, _('Withdrawal') + transfer_type(money_transaction))
          end
        end
      elsif money_transaction.target_account == account_line.account
        paid_from = money_transaction.source_account
        if paid_from.class == BidAccount
          if paid_from.bid
            if money_transaction.operation_code == TRANSFER_REFUND_FROM_BID_ESCROW
              for_what = content_tag(:span, _('Refund for unused funds on %s (%s revision) to %s')%[paid_from.bid.chat.revision.project.name, paid_from.bid.chat.revision.name, paid_from.bid.revision_language.language.nname])
            else
              for_what = content_tag(:span, _('Payment from translation of %s (%s revision) to %s')%[paid_from.bid.chat.revision.project.name, paid_from.bid.chat.revision.name, paid_from.bid.revision_language.language.nname])
            end
            url = url_for(:controller=>:bids, :action=>:show, :project_id=>paid_from.bid.chat.revision.project_id, :revision_id=>paid_from.bid.chat.revision_id, :chat_id=>paid_from.bid.chat_id, :id=>paid_from.bid)
          else
            for_what = content_tag(:span, _('Refund from canceled bid'))
          end
        elsif paid_from.class == ExternalAccount
          for_what = content_tag(:span, _('Deposit from %s account. ') % ExternalAccount::NAME[paid_from.external_account_type])
          if money_transaction.owner.class == Invoice
            invoice = money_transaction.owner
            url = url_for(:action=>:invoice, :id=>invoice.id)
            if !invoice.txn.blank?
              details << [_('Paid from'),ExternalAccount::NAME[invoice.payment_processor] + ' ' + invoice.txn]
            else
              details << [_('Pending payment'),'']
            end
            details << [_('Client information'),invoice.company || invoice.default_company]
            if invoice.cms_requests.present?
              details << ["Amount reserved for translation jobs #{invoice.cms_requests.pluck(:id).to_sentence}.", '']
            end
          else
            details << ['Transfer Type', transfer_type(money_transaction)]
          end
        elsif money_transaction.operation_code == TRANSFER_PAYMENT_FOR_INSTANT_TRANSLATION
          for_what = content_tag(:span, _('Instant text translation')+" "+money_transaction.owner_id.to_s)
        elsif [TRANSFER_PAYMENT_FROM_RESOURCE_TRANSLATION,TRANSFER_PAYMENT_FROM_RESOURCE_REVIEW].include?(money_transaction.operation_code)
          if money_transaction.owner and money_transaction.owner.resource_string and money_transaction.owner.resource_string.text_resource
            if money_transaction.operation_code == TRANSFER_PAYMENT_FROM_RESOURCE_TRANSLATION
              for_what = content_tag(:span, _('Software localization from %s to %s'%[money_transaction.owner.resource_string.text_resource.language.nname,money_transaction.owner.language.nname]))
            else
              for_what = content_tag(:span, _('Review of Software localization from %s to %s'%[money_transaction.owner.resource_string.text_resource.language.nname,money_transaction.owner.language.nname]))
            end
            details << ["Project", money_transaction.owner.resource_string.text_resource.name]
            details << ["Label", "#{money_transaction.owner.resource_string.context}##{money_transaction.owner.resource_string.token}"]
            url = url_for(:controller=>:resource_strings, :action=>:show, :text_resource_id=>money_transaction.owner.resource_string.text_resource, :id=>money_transaction.owner.resource_string)
          else
            for_what = _('Translation of deleted software localization project')
          end
        elsif money_transaction.operation_code == TRANSFER_REFUND_FOR_RESOURCE_TRANSLATION
          if money_transaction.source_account.resource_language
            language_name = money_transaction.source_account.resource_language.language.name
            text_resource = money_transaction.source_account.resource_language.text_resource
            for_what = content_tag(:span, "Refund from project #{link_to text_resource.name, text_resource_path(text_resource)} from language #{language_name}".html_safe)
          else
            for_what = content_tag(:span, "Refund from deleted software project")
          end
        elsif money_transaction.operation_code == TRANSFER_PAYMENT_FROM_KEYWORD_LOCALIZATION
          begin
            for_what = content_tag(:span, "Keyword localization on project #{money_transaction.source_account.keyword_project.owner.project_name}")
          rescue
            for_what = content_taG(:span, "From Target Accound: Keyword localization on project #{money_transaction.target_account.keyword_project.owner.project_name}")
          end
        else
          for_what = content_tag(:span) {
            concat 'Deposit of '.html_safe
            concat transfer_type(money_transaction)
          }
        end
        res = content_tag(:span, for_what, class: 'refund')
      elsif money_transaction.affiliate_account == account_line.account
        # affiliate payment
        res = content_tag(:span, _('Payment for affiliate comission'))
        target_account_line = money_transaction.account_lines.select{|acl| money_transaction.target_account == acl.account }.first
        if target_account_line
          description = money_transaction_details(target_account_line, money_transaction)
          description = sanitize(description, :tags => []) unless @user.has_supporter_privileges?
          details << ["Details", description]
        end
      else
        res = content_tag(:span, "money transaction: #{money_transaction.id}, account_line: #{account_line.id}")
      end

      if url && res
        concat link_to(res, url)
      else
        concat res
      end

      if details.length > 0
        details.each do |d|
          concat content_tag(:p) {
            concat content_tag(:span, d[0])
            concat ' '.html_safe
            concat content_tag(:b, pre_format(d[1]))
            concat '<br />'.html_safe
          }
        end
      end
    }
  rescue NoMethodError => e
    '-- The Project or language for this transaction does not longer exists --'
  end

  def show_account(account)
    account.identifier
  end

  def edit_account(account)
    _('Editing: %s') % account.identifier
  end

  def account_lines_header(account)

    pager = ::Paginator.new(account.account_lines.count, PER_PAGE) do |offset, per_page|
      account.account_lines.order('account_lines.id DESC').offset(offset).limit(per_page)
    end

    last_account_lines = pager.page(params[:page])

    total_account_lines = account.account_lines.count
    note = if last_account_lines.number == 0
             _('This account has no transactions yet')
           elsif last_account_lines.number != total_account_lines
             _('Last %d transactions in this account. %s') % [PER_PAGE, link_to(_('All transactions'), controller: :finance, action: :account_history, id: account.id)]
           else
             _('All transactions in this account')
           end

    if last_account_lines.number > 0
      note += ' &nbsp; | &nbsp; ' + link_to(_('All deposits'), action: :deposits, id: account.id)
      note += ' &nbsp; | &nbsp; ' + link_to(_('All withdrawals'), action: :withdrawals, id: account.id)
    end

    res = infotab_top(_('%s account') % account.currency.disp_name, note)
    if last_account_lines.number != 0
      res += render(partial: 'account_lines', locals: { account_lines: last_account_lines })
    end
    res
  end

  def account_owner_link(account)
    if account.class == UserAccount
      user_link account.normal_user
    elsif account.class == BidAccount
      bid = account.bid
      link_to(_('Bid on project: %s' % bid.revision_language.project_name), controller: :bids, action: :show, id: bid.id, chat_id: bid.chat_id, revision_id: bid.chat.revision_id, project_id: bid.chat.revision.project_id)
    elsif account.class == ResourceLanguageAccount
      res = _('Software project %s to %s. <b>Translator:</b> %s') % [
        link_to(account.resource_language.text_resource.name.to_s, controller: :resource_chats, action: :show, text_resource_id: account.resource_language.text_resource.id, id: account.resource_language.selected_chat.id),
        "<b>#{account.resource_language.language.name}</b>" + (account.resource_language.review_enabled? ? ' with review' : ''),
        user_link(account.resource_language.selected_chat.translator)
      ]

      if account.resource_language.review_enabled?
        managed_work = account.resource_language.managed_work
        res << ' <b>Reviewer:</b> %s' % (managed_work.translator ? user_link(managed_work.translator) : 'Unassigned')
      end

      res
    elsif account.class == TaxAccount
      'TaxAccount'
    else
      'some account'
    end
  end

  def translator_link(_account_line, money_transaction)
    user = nil
    if money_transaction.target_account.class == BidAccount
      chat = money_transaction.target_account.bid.chat
      user = chat.translator unless chat.translator.blank?
    elsif money_transaction.target_account.class == UserAccount
      user = money_transaction.target_account.normal_user
    end
    return user_link(user) if user && user[:type] == 'Translator'
  end

  def account_balance_report(account)
    currency_name = account.currency.disp_name
    expenses, pending_cms_target_languages, pending_web_messages = account.pending_total_expenses
    content_tag(:p) do
      concat _('Total balance: %.2f') % [account.total_balance]
      concat ' '.html_safe + currency_name.html_safe
      concat ' | '.html_safe
      # this is a hack to display on finance page planned expenses with money already in PendingMoneyAccount
      concat _('Planned expenses: %.2f') % [account.adjusted_expenses]
      concat ' '.html_safe + currency_name
      concat content_tag(:span) {
        concat ' ('
        details_links = []
        unless pending_cms_target_languages.empty?
          details_links << link_to(_('%d website translation documents') % pending_cms_target_languages.length, action: :pending_cms_requests, id: account.id)
        end
        unless pending_web_messages.empty?
          details_links << link_to(_('%d instant translation jobs') % pending_web_messages.length, controller: :web_messages, action: :index, translation_status: TRANSLATION_NEEDED, set_args: 1)
        end
        details_links.each { |link| concat link + (', ' unless link == details_links.last) }
        concat ') '
      }
      concat ' | '.html_safe
      concat _('Available balance: %.2f') % (account.available_balance)
    end
  end

  def link_to_money_account_owner(money_account)
    @account.owner_id # without this the link is not generated, wtf?

    case money_account.type
    when 'BidAccount'
      link_to('Bid Account', project_revision_chat_url(money_account.bid.revision.project, money_account.bid.revision, money_account.bid.chat))
    when 'KeywordAccount'
      'Keyword Account'
    when 'ResourceLanguageAccount'
      link_to('Software Project ' + money_account.resource_language.text_resource.name, text_resource_url(money_account.resource_language.text_resource))
    when 'RootAccount'
      'internal system account'
    when 'TaxAccount'
      'Tax Account'
    when 'UserAccount'
      user_link(money_account.normal_user)
    else
      money_account.type
    end
  end

  def vat_percent_from_amount(total, vat)
    percent = (((vat * 100) / total) * 2).round / 2.0
    percent.to_i == percent ? percent.to_i : percent
  end

end
