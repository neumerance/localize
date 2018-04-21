module ChatsHelper

  def bits_list(val)
    res = []
    left = val
    i = 1
    while left != 0
      if (left & i) != 0
        res << i
        left &= ~i
      end
      i = i << 1
    end
    res
  end

  def confirmation_question(action, completion_percentage, is_ta_project)
    if action == BID_ACTION_DELETE_BID
      _('Are you sure you want to delete this bid?')
    elsif action == BID_ACTION_REFUSE_BID
      _('Are you sure you want to refuse this bid?')
    elsif is_ta_project && (action == BID_ACTION_FINALIZE_WORK) && (completion_percentage != 100)
      _('Work on this language is not done. Are you sure you want to accept it as complete?')
    elsif (action == BID_ACTION_DECLARE_DONE) && !is_ta_project
      _('You are declaring this work as complete!') + "\n\n" + _('1. Did you review the work?') + "\n" + '2. Have you uploaded the translation as an attachment?'
    elsif action == BID_ACTION_SELF_COMPLETE
      _('You are declaring this work as complete!') + "\n\n" + _('Did you review the work?')
    end
  end

  def language_translation_status(bid_info)
    messages = []
    begin
      bid = Bid.find(bid_info[BID_INFO_BID_ID])
    rescue
      bid = nil
    end
    content_tag(:span) do
      if bid && BID_COMPLETE_STATUS.include?(bid.status)
        concat 'Work has been completed'
      else
        unless bid_info[BID_INFO_COMPLETION_PERCENTAGE].nil?
          if @revision.kind == TA_PROJECT
            concat 'Translation is '
            concat content_tag(:b, bid_info[BID_INFO_COMPLETION_PERCENTAGE].to_s + '% complete')
          elsif bid && (bid.status == BID_DECLARED_DONE)
            concat 'Translation completed'
          else
            concat 'Translation in progress'
          end
        end
        if bid_info[BID_INFO_EXPIRATION_TIME]
          concat '<br />'.html_safe
          concat 'Delivery deadline: '
          concat content_tag(:b, disp_time(bid_info[BID_INFO_EXPIRATION_TIME]))
        end
      end
    end
  end

  def bid_auto_accept_status(bid)
    revision = bid.revision

    if revision.auto_accept_amount && (revision.auto_accept_amount > 0)
      required_amount = bid.revision_language.missing_amount_for_auto_accept
      if required_amount == 0
        content_tag(:div, class: 'errorExplanation') do
          concat 'If you bid '.html_safe
          concat revision.auto_accept_amount; concat ' '.html_safe; concat revision.currency.disp_name.html_safe; concat ' '.html_safe; concat revision.payment_units
          concat 'for this project,<br />your bid will be automatically accepted.'.html_safe
        end
      end
    end
  end

  def issues_for_bid(bid_id, user)
    if bid_id
      bid = Bid.find(bid_id)
      return 'No bid selected yet' unless bid.won

      managed_work = bid.revision_language.managed_work
      reviewer = managed_work && (managed_work.active == MANAGED_WORK_ACTIVE) ? managed_work.translator : nil

      manager = [@project.manager, @project.manager.class.to_s]

      to_who =
        if user == @project.client || user == @project.manager
          [[@chat.translator, 'Translator']]
        elsif user == @chat.translator
          [manager]
        elsif user == reviewer
          [[@chat.translator, 'Translator'], manager]
        else
          []
        end
      if ((user == @project.client) || (user == @chat.translator)) && reviewer
        to_who << [reviewer, 'Reviewer']
      end

      return issues_for_object(bid.revision_language, to_who) unless to_who.empty?
    else
      'No bid selected yet'
    end
  end

end
