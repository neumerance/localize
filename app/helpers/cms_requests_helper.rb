module CmsRequestsHelper
  def link_to_translator_chat(cms_target_language)
    revision = cms_target_language.cms_request.revision
    if revision
      rl = revision.revision_languages.where('language_id=?', cms_target_language.language_id).first
      if rl
        bid = rl.selected_bid
        if bid
          chat = bid.chat
          link_to(_('Chat with translator'), controller: :chats, action: :show, project_id: chat.revision.project.id, revision_id: chat.revision.id, id: chat.id)
        else
          content_tag :i, _('No bid available (Translator have not accepted this job yet)')
        end
      end
    end
  end

  def action_buttons(cms_request)
    res = []

    if @user.has_supporter_privileges?
      if cms_request.can_cancel?
        if @user.has_supporter_privileges?
          res << button_to(_('Delete bidding project and reset CmsRequest'), { action: :reset, id: cms_request.id }, 'data-confirm' => _('[SUPPORTER WARNING] Are you sure you want to RESET this project? This will delete the associated bidding project for this job, delete any version uploaded with TA, delete all comm_errors and request TAS to process again as if it were new.'))
        end
      end

      if cms_request.pending_tas == 1
        res << button_to(_('Retry TAS processing'), action: :retry, id: cms_request.id)
      else
        if cms_request.status == CMS_REQUEST_DONE
          res << button_to(_('Redo translation'), { action: :redo, id: cms_request.id }, 'data-confirm' => _('Are you sure you want to redo this translation? The completed translation will be discarded.'))
        end
      end
    end

    if (@user == @website.client) || (@user.alias_of?(@website.client) && @user.can_modify?(@website)) || @user.has_supporter_privileges?
      if cms_request.can_cancel?
        res << button_to(_('Cancel translation'), { action: :cancel_translation, id: cms_request.id }, 'data-confirm' => _('Are you sure you want to cancel the translation of this document?'))
      end

      if cms_request.permlink.present?
        res << link_to(_('View original'), cms_request.permlink, target: '_blank')
      end

      unless cms_request.pending_tas == 1
        if (cms_request.status == CMS_REQUEST_DONE) || (cms_request.status == CMS_REQUEST_TRANSLATED)
          res << button_to(_('Resend to CMS'), action: :resend, id: cms_request.id)
        end
      end
    end
    res = res.present? ? res.join(' &nbsp; | &nbsp; ') : ''
    res.html_safe
  end

  def comm_errors_summary(comm_errors)
    res = '<span class="comment">' + _('%d comm errors') % comm_errors.length + '</span>'
    active_comm_errors = []
    comm_errors.each do |comm_error|
      active_comm_errors << comm_error if comm_error.status == COMM_ERROR_ACTIVE
    end

    unless active_comm_errors.empty?
      res += ' <span class="warning">(' + _('%d active') % active_comm_errors.length + ')</span>'
    end

    res
  end

  def show_languages(cms_request)
    content_tag(:span) do
      cms_request.cms_target_languages.each do |ctl|
        if ctl.word_count
          concat content_tag(:span) {
            concat cms_request.language.nname + ' '.html_safe
            concat ' &raquo; '.html_safe
            concat ctl.language.nname
            concat ' '.html_safe
            concat content_tag(:span, _('%d words') % ctl.word_count, class: 'comment')
          }
        else
          concat content_tag(:span) {
            concat cms_request.language.nname + ' '.html_safe
            concat ' &raquo; '.html_safe
            concat ctl.language.nname
          }
        end
      end
    end
  end

  def review_status(cms_request)
    # check if the work is already in progress
    res = []
    if cms_request.revision
      cms_request.revision.revision_languages.each do |rl|
        if rl.managed_work && (rl.managed_work.active == MANAGED_WORK_ACTIVE)
          if rl.managed_work.translation_status == MANAGED_WORK_WAITING_FOR_REVIEWER
            res << _('Waiting for reviewer')
          elsif rl.managed_work.translation_status == MANAGED_WORK_COMPLETE
            res << _('Review completed')
          elsif rl.managed_work.translation_status == MANAGED_WORK_REVIEWING
            res << _('Review in progress')
          elsif rl.managed_work.translation_status == MANAGED_WORK_CREATED
            res << _('Will start after translation is finished')
          end
        else
          res << _('Review disabled')
        end
      end
    end
    res.join('<br />')
  end

  def review_status_text(cms_request)
    rl = cms_request.revision&.revision_language
    if rl
      if rl.managed_work && (rl.managed_work.active == MANAGED_WORK_ACTIVE)
        if rl.managed_work.translation_status == MANAGED_WORK_WAITING_FOR_REVIEWER
          _('Waiting for reviewer')
        elsif rl.managed_work.translation_status == MANAGED_WORK_COMPLETE
          _('Review completed')
        elsif rl.managed_work.translation_status == MANAGED_WORK_REVIEWING
          _('Review in progress')
        elsif rl.managed_work.translation_status == MANAGED_WORK_CREATED
          _('Will start after translation is finished')
        end
      else
        _('Review disabled')
      end
    else
      if cms_request.review_enabled
        _('Will start after translation is finished')
      elsif cms_request.review_enabled == false # If it's nil, it does not mean review is disabled
        _('Review disabled')
      else # It's nil. More details on the comments of icldev-2791
        _('Client will enable or disable before payment')
      end
    end
  end

  def cms_requests_details(website, cms_requests)
    offers = {}
    money_account = website.client.find_or_create_account(DEFAULT_CURRENCY_ID)

    res = []
    cms_requests.each do |cms_request|
      res << '<tr>'
      res << "<td>#{cms_request.id}</td>"
      res << "<td>#{disp_date(cms_request.created_at)}</td>"
      res << '<td class="text-left">'
      if (@user == @website.client) || (@user.alias_of?(@website.client) && @user.can_modify?(@website)) || @user.has_supporter_privileges?
        if cms_request.can_cancel?
          res << check_box_tag('cancellable_jobs[]', cms_request.id, false, class: 'm-r-5 cancel-checkbox')
        end
      end
      res << link_to(h(cms_request.title), action: :show, id: cms_request.id).to_s
      res << '</td>'
      res << "<td>#{show_languages(cms_request)}</td>"
      res << '<td>'
      if cms_request.cms_target_language.translator
        res << "#{user_link(cms_request.cms_target_language.translator)} | #{link_to_translator_chat(cms_request.cms_target_language)}"
      end
      res << '</td>'
      res << '<td>'
      res << cms_request.detailed_status
      if @user.has_supporter_privileges? && !cms_request.comm_errors.empty?
        res << "&nbsp; #{comm_errors_summary(cms_request.comm_errors)}"
      end
      res << '</td>'
      res << '<td>'

      res << review_status_text(cms_request)

      res << '</td>'
      res << "<td>#{action_buttons(cms_request)}</td>"
      res << '</tr>'
    end
    res.join.html_safe
  end

  def start_translate_button(cms)
    content_tag :p do
      if cms.xliff_processed
        concat submit_tag('Start translating', style: 'font-weight: bold; padding: 0.5em;', data: { disable_with: 'Start translating' })
        concat ' | '.html_safe
        concat link_to('Cancel', controller: :translator)
      else
        content_tag :span, 'We are currently processing document, it will be available for translation soon.'
      end
    end
  end

end
