class Reminder < ApplicationRecord
  belongs_to :normal_user
  belongs_to :owner, polymorphic: true
  belongs_to :website

  # for eager loading
  belongs_to :arbitration, -> { where(reminders: { owner_type: 'Arbitration' }) }, foreign_key: 'owner_id'
  belongs_to :bid, -> { where(reminders: { owner_type: 'Bid' }) }, foreign_key: 'owner_id'
  belongs_to :chat, -> { where(reminders: { owner_type: 'Chat' }) }, foreign_key: 'owner_id'
  belongs_to :invoice, -> { where(reminders: { owner_type: 'Invoice' }) }, foreign_key: 'owner_id'
  belongs_to :issue, -> { where(reminders: { owner_type: 'Issue' }) }, foreign_key: 'owner_id'
  belongs_to :managed_work, -> { where(reminders: { owner_type: 'ManagedWork' }) }, foreign_key: 'owner_id'
  belongs_to :resource_chat, -> { where(reminders: { owner_type: 'ResourceChat' }) }, foreign_key: 'owner_id'
  belongs_to :revision, -> { where(reminders: { owner_type: 'Revision' }) }, foreign_key: 'owner_id'
  belongs_to :revision_language, -> { where(reminders: { owner_type: 'RevisionLanguage' }) }, foreign_key: 'owner_id'
  belongs_to :support_ticket, -> { where(reminders: { owner_type: 'SupportTicket' }) }, foreign_key: 'owner_id'
  belongs_to :user, -> { where(reminders: { owner_type: 'User' }) }, foreign_key: 'owner_id'
  belongs_to :website_translation_contract, -> { where(reminders: { owner_type: 'WebsiteTranslationContract' }) }, foreign_key: 'owner_id'

  scope :by_owner_and_normal_user, ->(owner, to_who) { where(owner: owner, normal_user: to_who) }
  scope :by_owner, ->(owner) { where(owner: owner) }

  def project_id
    if owner.class == Project
      owner.id
    elsif owner.class == Revision
      owner.project_id
    elsif owner.class == Chat
      owner.revision.project_id
    elsif owner.class == Bid
      owner.chat.revision.project_id
    end
  end

  def revision_id
    if owner.class == Revision
      owner.id
    elsif owner.class == Chat
      owner.revision_id
    elsif owner.class == Bid
      owner.chat.revision_id
    end
  end

  def chat_id
    if owner.class == Chat
      owner.id
    elsif owner.class == Bid
      owner.chat_id
    end
  end

  def print_details(user)
    if !owner
      'Expired - %d' % id
    elsif event == EVENT_NEW_BID
      _('New bid for translating [b]%s[/b] to [b]%s[/b] by [b]%s[/b]') % [owner.chat.revision.project.name, owner.revision_language.language.nname, owner.chat.translator.full_name]
    elsif event == EVENT_BID_ACCEPTED
      _('Bid to translate [b]%s[/b] to [b]%s[/b] was accepted') % [owner.chat.revision.project.name, owner.revision_language.language.nname]
    elsif event == EVENT_BID_COMPLETED
      _('Translation of [b]%s[/b] to [b]%s[/b] is complete') % [owner.chat.revision.project.name, owner.revision_language.language.nname]
    elsif event == EVENT_BID_WAITING_PAYMENT
      _('Deposit pending for [b]%s[/b] on [b]%s[/b]') % [owner.chat.revision.project.name, owner.revision_language.language.nname]
    elsif event == EVENT_NEW_MESSAGE
      from_name = (user[:type] == 'Client') ? owner.translator.full_name : owner.revision.project.manager.full_name
      if from_name.present?
        return _('New message on [b]%s[/b] from [b]%s[/b]') % [owner.revision.project.name, from_name]
      else
        return nil
      end
    elsif (event == EVENT_ARBITRATION_RESPONSE_NEEDED) || (event == EVENT_ARBITRATION_RESPONSE_REQUIRED)
      if expiration
        _('You need to respond to arbitration on [b]%s[/b] by [b]%s[/b]') % [owner.object.chat.revision.project.name, expiration.strftime(TIME_FORMAT_STRING)]
      else
        _('You need to respond to arbitration on [b]%s[/b]') % owner.object.chat.revision.project.name
      end
    elsif event == EVENT_ARBITRATION_OFFER_MADE
      _('You received an offer to end the arbitration on [b]%s[/b]') % [owner.object.chat.revision.project.name]
    elsif event == EVENT_ARBITRATION_CLOSED
      _('The arbitration on [b]%s[/b] has been closed') % [owner.object.chat.revision.project.name]
    elsif event == EVENT_BIDDING_ON_REVISION_CLOSED
      _('Bidding on [b]%s - %s revision[/b] is now closed') % [owner.project.name, owner.name]
    elsif event == EVENT_WORK_NEEDS_TO_COMPLETE
      _('The deadline for translating [b]%s[/b] to [b]%s[/b] has expired') % [owner.chat.revision.project.name, owner.revision_language.language.nname]
    elsif event == EVENT_BID_ABOUT_TO_GO_TO_ARBITRATION
      _('You need to respond to translation of [b]%s[/b] to [b]%s[/b] (completed %s)') % [owner.chat.revision.project.name, owner.revision_language.language.nname, owner.expiration_time.strftime(DATE_FORMAT_STRING)]
    elsif event == EVENT_BID_WENT_TO_ARBITRATION
      _('Translation of [b]%s[/b] to [b]%s[/b] went to arbitration') % [owner.chat.revision.project.name, owner.revision_language.language.nname]
    elsif event == EVENT_TICKET_UPDATE
      _('Support ticket [b]%s[/b] was answered') % truncate(owner.subject, 20, '...')
    elsif event == EVENT_TICKET_CLOSED
      _('Support ticket [b]%s[/b] was closed') % truncate(owner.subject, 20, '...')
    elsif event == EVENT_TICKET_FROM_SUPPORTER
      _('A supporter needs your attention: [b]%s[/b]') % truncate(owner.subject, 20, '...')
    elsif event == EVENT_WORK_DONE
      _('Work has completed on translation of [b]%s[/b] to [b]%s[/b]') % [owner.revision.project.name, owner.language.nname]
    elsif event == EVENT_INVOICE_DUE
      _('Your payment for %.2f %s is pending') % [owner.total_amount, owner.currency.name]
    elsif event == EVENT_NEW_WEBSITE_TRANSLATION_MESSAGE
      from_name = (user[:type] == 'Client') ? owner.try(:translator).try(:full_name) : owner.try(:website_translation_offer).try(:website).try(:client).try(:full_name)
      if from_name.present?
        return _('New message on [b]%s[/b] from [b]%s[/b]') % [owner.website_translation_offer.website.name, from_name]
      else
        return nil
      end
    elsif event == EVENT_NEW_WEBSITE_TRANSLATION_CONTRACT
      _('[b]%s[/b] is interested in translating [b]%s[/b] from [b]%s[/b] to [b]%s[/b]') % [owner.translator.full_name, owner.website_translation_offer.website.name, owner.website_translation_offer.from_language.nname, owner.website_translation_offer.to_language.nname]
    elsif event == EVENT_NEW_RESOURCE_TRANSLATION_MESSAGE
      from_name = (user[:type] == 'Client') ? owner.try(:translator).try(:full_name) : owner.try(:resource_language).try(:text_resource).try(:client).try(:full_name)
      if from_name.present?
        return _('New message on [b]%s[/b] from [b]%s[/b]') % [owner.resource_language.text_resource.name, from_name]
      else
        return nil
      end
    elsif event == EVENT_NEW_RESOURCE_TRANSLATION_CONTRACT
      _('[b]%s[/b] is interested in translating [b]%s[/b] to [b]%s[/b]') % [owner.translator.full_name, owner.resource_language.text_resource.name, owner.resource_language.language.nname]
    elsif event == EVENT_NEW_MANAGED_WORK_MESSAGE
      _('New message on translation review')
    elsif event == EVENT_NEW_ISSUE_MESSAGE
      _('New message on tracked-issue')
    elsif event == EVENT_UPDATE_VAT_NUMBER
      _('If you reside in the EU please update your [b]country of residence[/b] and [b]VAT number[/b].')
    else
      nil
    end
  rescue => e
    Rails.logger.error "ERROR: #{e.message} #{e.inspect}"
  end

  def link_to_handle(user)
    if !owner
      return nil
    elsif (event == EVENT_NEW_BID) || (event == EVENT_BID_ACCEPTED) || (event == EVENT_BID_COMPLETED) || (event == EVENT_WORK_NEEDS_TO_COMPLETE) || (event == EVENT_BID_ABOUT_TO_GO_TO_ARBITRATION)
      return { controller: '/chats', action: 'show', id: owner.chat_id, revision_id: owner.chat.revision_id, project_id: owner.chat.revision.project_id }
    elsif event == EVENT_BID_WAITING_PAYMENT
      return owner.revision
    elsif event == EVENT_NEW_MESSAGE
      res = { controller: '/chats', action: 'show', id: owner.id, revision_id: owner.revision_id, project_id: owner.revision.project_id, anchor: 'comments' }
      if user && owner.revision.cms_request && (user == owner.revision.cms_request.website.client)
        res[:wid] = owner.revision.cms_request.website_id
        res[:accesskey] = owner.revision.cms_request.website.accesskey
      end
      return res
    elsif (event == EVENT_ARBITRATION_RESPONSE_NEEDED) ||
        (event == EVENT_ARBITRATION_RESPONSE_REQUIRED) ||
        (event == EVENT_ARBITRATION_OFFER_MADE) ||
        (event == EVENT_ARBITRATION_CLOSED)
      return { controller: '/arbitrations', action: 'show', id: owner.id }
    elsif event == EVENT_BIDDING_ON_REVISION_CLOSED
      return { controller: '/revisions', action: 'show', project_id: owner.project_id, id: owner.id }
    elsif event == EVENT_BID_WENT_TO_ARBITRATION
      return { controller: '/arbitrations', action: 'show', id: owner.arbitration.id }
    elsif (event == EVENT_TICKET_UPDATE) || (event == EVENT_TICKET_CLOSED) || (event == EVENT_TICKET_FROM_SUPPORTER)
      return { controller: '/support', action: 'show', id: owner_id }
    elsif event == EVENT_WORK_DONE
      return { controller: '/revisions', action: 'show', project_id: owner.revision.project_id, id: owner.revision_id, anchor: 'languages' }
    elsif event == EVENT_INVOICE_DUE
      begin
        return owner.source if owner.source
      rescue
      end
      return { controller: '/finance', action: 'invoice', id: owner.id }
    elsif (event == EVENT_NEW_WEBSITE_TRANSLATION_MESSAGE) || (event == EVENT_NEW_WEBSITE_TRANSLATION_CONTRACT)
      return { controller: '/website_translation_contracts', action: :show, website_id: owner.website_translation_offer.website_id, website_translation_offer_id: owner.website_translation_offer_id, id: owner.id }
    elsif (event == EVENT_NEW_RESOURCE_TRANSLATION_MESSAGE) || (event == EVENT_NEW_RESOURCE_TRANSLATION_CONTRACT)
      return { controller: '/resource_chats', action: :show, text_resource_id: owner.resource_language.text_resource_id, id: owner.id }
    elsif event == EVENT_NEW_MANAGED_WORK_MESSAGE
      return { controller: '/managed_works', action: :show, id: owner.id }
    elsif event == EVENT_NEW_ISSUE_MESSAGE
      return { controller: '/issues', action: :show, id: owner.id, key: owner.key }
    elsif event == EVENT_UPDATE_VAT_NUMBER
      return { controller: '/users', action: :show, id: owner.id }
    else
      nil
    end
  rescue => e
    Rails.logger.error "ERROR: #{e.message} #{e.inspect}"
  end

  def truncate(str, max_length, replace)
    if str.length > (max_length - replace.length)
      str[0..(max_length - replace.length)] + replace
    else
      str
    end
  end

  def user_can_delete
    !PROTECTED_EVENTS.include?(event)
  end

end
