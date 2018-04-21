class ReminderMailer < ApplicationMailer
  helper :application
  layout :choose_layout

  default from: EMAIL_SENDER

  WELCOME_MAIL = 'ICanLocalize Team <hello@icanlocalize.com>'.freeze

  def choose_layout
    @use_wpml_template ? 'wpml_email' : 'email'
  end

  def generic(email, subject, message)
    @message = message

    mail(to: email, subject: subject)
  end

  def user_close_account(user)
    @user = user

    mail(
      to: WELCOME_MAIL,
      from: RAW_EMAIL_SENDER,
      reply_to: WELCOME_MAIL,
      subject: "New account closed: #{user.nickname}"
    )
  end

  def notify_translator_removed(project, translator, language)
    @client = project.client
    @translator = translator
    @language = language.name
    @project = project

    mail(
      to: @client.email,
      from: RAW_EMAIL_SENDER,
      reply_to: WELCOME_MAIL,
      subject: "#{translator.nickname} is not translating #{project.name} any longer"
    )
  end

  def offering_logo(client)
    @client = client

    attachment content_type: 'image/png', body: File.read('public/Translated by -circle.png')
    attachment content_type: 'image/png', body: File.read('public/Translated by -rectangle.jpg')

    mail(
      to: client.email,
      from: RAW_EMAIL_SENDER,
      reply_to: WELCOME_MAIL,
      subject: 'Logo "Translated by ICanLocalize"'
    )
  end

  def new_message(user, other, chat, message)
    @html_email = true
    @chat = chat
    @user = user
    @other = other
    @message = message
    @has_attachments = (message.attachments.count > 0)

    mail(
      to: user.email_with_name,
      subject: "#{EMAIL_OWNER_TXT}You have a new message on project #{chat.revision.project.name}"
    )
  end

  def arbitration_started(user, by_who, arbitration, arb_type)
    @html_email = true
    @user = user
    @by_who = by_who
    @arbitration = arbitration
    @arb_type = arb_type

    mail(
      to: user.email_with_name,
      subject: "#{EMAIL_OWNER_TXT}Arbitration created, your action is required"
    )
  end

  def arbitration_offer(user_id, by_who, arbitration, amount)
    @html_email = true
    @user = User.find(user_id)
    @by_who = by_who
    @arbitration = arbitration
    @amount = amount

    mail(
      to: @user.email_with_name,
      subject: "#{EMAIL_OWNER_TXT}Offer submitted to end the arbitration process"
    )
  end

  def arbitration_closed(user_id, arbitration, amount)
    html_email = true
    @user = User.find(user_id)
    @arbitration = arbitration
    @amount = amount

    mail(
      to: @user.email_with_name,
      subject: "#{EMAIL_OWNER_TXT}Arbitration closed"
    )
  end

  def new_message_in_arbitration(user_id, by_who, arbitration, body, response_deadline)
    @html_email = true
    @user = User.find(user_id)
    @by_who = by_who
    @arbitration = arbitration
    @body = body
    @response_deadline = response_deadline

    mail(
      to: @user.email_with_name,
      subject: "#{EMAIL_OWNER_TXT}You have a new message regarding an arbitration process"
    )
  end

  def new_version(user, version, by_user, stats_txt = nil)
    @html_email = true
    @version = version
    @user = user
    @by_user = by_user

    @stats_txt = stats_txt if !stats_txt.nil? && (stats_txt != '')

    mail(
      to: user.email_with_name,
      subject: "#{EMAIL_OWNER_TXT}A new version was uploaded for your project #{version.revision.project.name}"
    )
  end

  def work_complete(user, bid, by_user, reviewer)
    @html_email = true
    @content_type = 'text/html'
    @html_email = true
    @footer_with_recommend = true

    @bid      = bid
    @user     = user
    @by_user  = by_user
    @reviewer = reviewer

    mail(
      to: user.email_with_name,
      subject: "#{EMAIL_OWNER_TXT}Work on your project #{bid.revision_language.revision.project.name} has completed"
    )
  end

  def user_should_complete_registration(user, additional_message = nil, page_from = nil, extra_params = nil)
    @html_email = true
    @page_from = page_from
    @extra_params = extra_params

    @user               = user
    @signature          = user.signature
    @additional_message = additional_message

    if page_from == 'translation_analytics'
      @use_wpml_template = true

      mail(
        to: user.email_with_name,
        from: ANALYTICS_EMAIL_SENDER,
        reply_to: WELCOME_MAIL,
        subject: 'Confirm your registration'
      )
    else
      mail(
        to: user.email_with_name,
        subject: "#{EMAIL_OWNER_TXT}Confirm your registration"
      )
    end
  end

  def welcome_cms_user(user, control_screen)
    @user = user
    @control_screen = control_screen

    mail(
      to: user.email_with_name,
      subject: "#{EMAIL_OWNER_TXT}Your ICanLocalize account"
    )
  end

  def welcome_site_user(user)
    @html_email = true
    @user = user

    mail(
      to: user.email_with_name,
      subject: 'Welcome to ICanLocalize!',
      from: RAW_EMAIL_SENDER,
      reply_to: WELCOME_MAIL
    )
  end

  def follow_up_inactive_client(user)
    @user = user

    mail(
      to: user.email_with_name,
      from: RAW_EMAIL_SENDER,
      reply_to: WELCOME_MAIL,
      subject: 'Follow up from ICanLocalize'
    )
  end

  def contact_created(contact)
    @contact = contact

    mail(
      to: contact.email_with_name,
      subject: "#{EMAIL_OWNER_TXT}Contact form confirmation"
    )
  end

  def contact_replied(contact, reply)

    @contact = contact
    @reply = reply

    mail(
      to: contact.email_with_name,
      subject: "#{EMAIL_OWNER_TXT}Re: #{truncate(contact.subject, 60, '...')}"
    )
  end

  def external_account_validation(account, user)
    @user = user
    @account = account

    mail(
      to: "#{user.full_real_name} <#{account.identifier}>",
      subject: "#{EMAIL_OWNER_TXT}E-Mail address validation required"
    )
  end

  def password_reset(user)
    @html_email = true
    @user = user

    @signature = user.signature if user.userstatus == USER_STATUS_NEW

    mail(
      to: user.email_with_name,
      subject: "#{EMAIL_OWNER_TXT}Password reset"
    )
  end

  def ta_getting_started_instructions(user)
    @user = user

    mail(
      to: user.email_with_name,
      subject: "#{EMAIL_OWNER_TXT}Getting started guide"
    )
  end

  def welcome_translator(user)
    @html_email = true
    @user = user

    mail(
      to: user.email_with_name,
      subject: "#{EMAIL_OWNER_TXT}Welcome to ICanLocalize"
    )
  end

  def new_ticket_by_supporter(support_ticket, alternative_opening = nil)
    @html_email = true
    @user = support_ticket.normal_user
    @support_ticket = support_ticket
    @message = support_ticket.messages[-1]
    @alternative_opening = alternative_opening

    mail(
      to: support_ticket.normal_user.email_with_name,
      subject: "#{EMAIL_OWNER_TXT} #{support_ticket.email_track_code} #{support_ticket.subject}"
    )
  end

  def ticket_replied(support_ticket)
    @html_email = true
    @user = support_ticket.normal_user
    @support_ticket = support_ticket
    @reply = support_ticket.messages[-1].body
    @content_type = 'text/html'
    @html_email = true

    mail(
      to: support_ticket.normal_user.email_with_name,
      subject: "#{EMAIL_OWNER_TXT}Re: #{support_ticket.email_track_code} #{support_ticket.subject}"
    )
  end

  def ticket_closed(support_ticket)
    @html_email = true
    @user = support_ticket.normal_user
    @support_ticket = support_ticket

    mail(
      to: support_ticket.normal_user.email_with_name,
      subject: "#{EMAIL_OWNER_TXT}Re: #{support_ticket.email_track_code} #{support_ticket.subject}"
    )
  end

  def notify_support_about_new_ticket(recipients, support_ticket)
    @html_email = true
    @user = support_ticket.normal_user
    @support_ticket = support_ticket
    @message = support_ticket.messages[-1]

    mail(
      to: 'your_email@domain.com',
      bcc: recipients,
      subject: "#{EMAIL_OWNER_TXT}#{support_ticket.subject}"
    )
  end

  def notify_support_about_ticket_update(admin, support_ticket)
    @html_email = true
    @user = support_ticket.normal_user
    @support_ticket = support_ticket
    @message = support_ticket.messages[-1]

    mail(
      to: admin.email,
      subject: "#{EMAIL_OWNER_TXT}Re: #{support_ticket.subject}"
    )
  end

  def profile_updated(user, message)
    @user = user
    @message = message

    mail(
      to: user.email_with_name,
      subject: "#{EMAIL_OWNER_TXT}Your profile has been updated"
    )
  end

  def new_bid(user, translator, bid)
    @html_email = true
    @user = user
    @translator = translator
    @bid = bid

    mail(
      to: user.email_with_name,
      subject: "#{EMAIL_OWNER_TXT}New bid was posted for #{bid.chat.revision.project.name}"
    )
  end

  def auto_accepted_bid(user, translator, bid)
    @html_email = true
    @user = user
    @translator = translator
    @bid = bid

    mail(
      to: user.email_with_name,
      subject: "#{EMAIL_OWNER_TXT}Translation of #{bid.chat.revision.project.name} started!"
    )
  end

  def bid_accepted(user, bid)
    @user = user
    @bid = bid
    @html_email = true

    mail(
      to: user.email_with_name,
      subject: "#{EMAIL_OWNER_TXT}Your bid has been accepted"
    )
  end

  def not_won_message(bid)
    @user = bid.chat.translator
    @bid = bid

    mail(
      to: bid.chat.translator.email_with_name,
      subject: "#{EMAIL_OWNER_TXT}Your bid was not accepted"
    )
  end

  def project_assigned(user, bid)
    @user = user
    @bid = bid

    mail(
      to: user.email_with_name,
      subject: "#{EMAIL_OWNER_TXT}A project has been assigned to you"
    )
  end

  def bid_finalized(user, bid)
    @html_email = true
    @user = user
    @bid = bid
    @has_verified_account = !user.external_accounts.empty?

    mail(
      to: user.email_with_name,
      subject: "#{EMAIL_OWNER_TXT}Your work has been accepted as complete"
    )
  end

  def new_projects_for_translator(email_subject, user, revisions, web_messages, messages_to_review, open_website_translation_offers, open_cms_requests, open_text_resource_projects, open_managed_works, _download_needed)
    web_messages_wc = 0
    (web_messages + messages_to_review).each { |message| web_messages_wc += message.word_count }

    missing_categories = []
    open_website_translation_offers.each do |offer|
      if offer.website.category && !missing_categories.include?(offer.website.category) && !user.categories.include?(offer.website.category)
        missing_categories << offer.website.category
      end
    end

    @user                            = user
    @revisions                       = revisions
    @web_messages_wc                 = web_messages_wc
    @open_website_translation_offers = open_website_translation_offers
    # New CmsRequests from language pairs where the translator is already
    # assigned to (from the specific websites that have assigned the translator).
    # He can (and should) get started with the translation immediately.
    @open_cms_requests               = open_cms_requests
    @open_text_resource_projects     = open_text_resource_projects
    @open_managed_works              = open_managed_works
    @missing_categories              = missing_categories

    mail(
      to: user.email_with_name,
      subject: "#{EMAIL_OWNER_TXT}#{email_subject}"
    )
  end

  def account_setup_reminder(user, missing_items_txt)
    @user = user
    @missing_items_txt = missing_items_txt

    mail(
      to: user.email_with_name,
      subject: "#{EMAIL_OWNER_TXT}Complete your account setup today"
    )
  end

  def account_setup_done(user, revisions, send_notification)
    @html_email = true
    @user = user
    @revisions = revisions if revisions && !revisions.empty?
    @send_notification = send_notification

    mail(
      to: user.email_with_name,
      subject: "#{EMAIL_OWNER_TXT}Your account setup is complete!"
    )
  end

  def error_created(to, error_report)
    @error_report = error_report

    mail(
      to: to,
      subject: "#{Rails.env} ICanLocalize error notification"
    )
  end

  def newsletter(user, newsletter)
    @newsletter = newsletter
    @user = user
    @body = newsletter.body_markup(false)
    mail(
      to: user.email_with_name,
      from: NEWSLETTER_SENDER,
      subject: "[ICanLocalize newsletter] #{newsletter.subject}"
    )
  end

  def account_auto_created(user, message)
    @html_email = true
    @user    = user
    @message = message

    mail(
      to: user.email_with_name,
      subject: "#{EMAIL_OWNER_TXT}Information about your translation work"
    )
  end

  def invite_translator(translator, client, private_translator, newuser)
    @html_email = true
    @translator         = translator
    @client             = client
    @private_translator = private_translator
    @newuser            = newuser

    mail(
      to: translator.email_with_name,
      subject: "#{EMAIL_OWNER_TXT}You are invited to translate for #{client.full_real_name}"
    )
  end

  def cms_project_needs_money(user, website, invoice)
    @user = user
    @website = website
    @invoice = invoice

    with_user_locale(user) do
      mail(
        to: user.email_with_name,
        subject: EMAIL_OWNER_TXT + _('Funding needed for project %s') % website.name
      )
    end
  end

  def new_application_for_cms_translation(user, website_translation_contract, message)
    @html_email = true
    @user                         = user
    @translator                   = website_translation_contract.translator
    @website_translation_contract = website_translation_contract
    @website_translation_offer    = website_translation_contract.website_translation_offer
    @website                      = website_translation_contract.website_translation_offer.website
    @message                      = message

    with_user_locale(user) do
      mail(
        to: user.email_with_name,
        subject: EMAIL_OWNER_TXT + _('Application to translate your project %s') % website_translation_contract.website_translation_offer.website.name
      )
    end
  end

  def new_message_for_cms_translation(user, website_translation_contract, message)
    @html_email = true
    @user                         = user
    @website_translation_contract = website_translation_contract
    @message                      = message
    @html_email                   = true

    with_user_locale(user) do
      mail(
        to: user.email_with_name,
        subject: EMAIL_OWNER_TXT + _('New message on project %s') % website_translation_contract.website_translation_offer.website.name
      )
    end
  end

  def accepted_application_for_cms_translation(user, website_translation_contract)
    @html_email = true
    @user = user
    @website_translation_contract = website_translation_contract
    pending_jobs, word_count = website_translation_contract.website_translation_offer.open_work_stats
    @pending_jobs = pending_jobs

    mail(
      to: user.email_with_name,
      subject: "#{EMAIL_OWNER_TXT}Your application to translate '#{website_translation_contract.website_translation_offer.website.name}' was accepted"
    )
  end

  def declined_application_for_cms_translation(user, website_translation_contract)
    @html_email = true
    @user = user
    @website_translation_contract = website_translation_contract

    mail(
      to: user.email_with_name,
      subject: "#{EMAIL_OWNER_TXT}Your application to translate '#{website_translation_contract.website_translation_offer.website.name}' was declined"
    )
  end

  def remind_about_cms_projects(user, cms_requests_count)
    @html_email = true
    @user = user
    @cms_requests_count = cms_requests_count

    mail(
      to: user.email_with_name,
      subject: "#{EMAIL_OWNER_TXT}Reminder - translation jobs waiting for you!"
    )
  end

  def work_can_resume(user, bid)
    @user = user
    @bid = bid

    mail(
      to: user.email_with_name,
      subject: "#{EMAIL_OWNER_TXT}Translation can continue"
    )
  end

  def old_web_messages_alert(user, missing_funding)
    @user = user
    @missing_funding = missing_funding

    with_user_locale(user) do
      mail(
        to: user.email_with_name,
        subject: EMAIL_OWNER_TXT + _('Instant Translation still not completed')
      )
    end
  end

  def notify_about_low_funding(user, account, expenses, pending_cms_target_languages, pending_web_messages)
    @html_email = true
    @user                         = user
    @account                      = account
    @expenses                     = expenses
    @pending_cms_target_languages = pending_cms_target_languages
    @pending_web_messages         = pending_web_messages

    with_user_locale(user) do
      mail(
        to: user.email_with_name,
        subject: EMAIL_OWNER_TXT + _('ALERT: Low funding - translations cannot begin')
      )
    end
  end

  def cms_translation_complete(cms_request)
    @html_email = true
    @user = cms_request.website.client
    @cms_request = cms_request

    with_user_locale(@user) do
      mail(
        to: @user.email_with_name,
        subject: EMAIL_OWNER_TXT + _('Document translation complete!')
      )
    end
  end

  def new_application_for_resource_translation(user, resource_chat, message)
    @html_email = true
    @user = user
    @resource_chat = resource_chat
    @message = message

    mail(
      to: user.email_with_name,
      subject: "#{EMAIL_OWNER_TXT}Application to translate your project '#{resource_chat.resource_language.text_resource.name}'"
    )
  end

  def new_message_for_resource_translation(user, resource_chat, message)
    @html_email = true
    @user = user
    @resource_chat = resource_chat
    @message = message

    mail(
      to: user.email_with_name,
      subject: "#{EMAIL_OWNER_TXT}New message on project '#{resource_chat.resource_language.text_resource.name}'"
    )
  end

  def accepted_application_for_resource_translation(user, resource_chat)
    @html_email = true
    @user = user
    @resource_chat = resource_chat

    mail(
      to: user.email_with_name,
      subject: "#{EMAIL_OWNER_TXT}Your application to translate '#{resource_chat.resource_language.text_resource.name}' was accepted"
    )
  end

  def declined_application_for_resource_translation(user, resource_chat)
    @html_email = true
    @user = user
    @resource_chat = resource_chat

    mail(
      to: user.email_with_name,
      subject: "#{EMAIL_OWNER_TXT}Your application to translate '#{resource_chat.resource_language.text_resource.name}' was declined"
    )
  end

  def other_application_accepted(user, resource_chat)
    @html_email = true
    @user = user
    @resource_chat = resource_chat

    mail(
      to: user.email_with_name,
      subject: "#{EMAIL_OWNER_TXT}Your application to translate '#{resource_chat.resource_language.text_resource.name}' was not accepted"
    )
  end

  def new_strings_in_resource(user, text_resource, string_count, word_count, deadline)
    @html_email = true
    @user = user
    @text_resource = text_resource
    @string_count = string_count
    @word_count = word_count
    @deadline = deadline

    mail(
      to: user.email_with_name,
      subject: "#{EMAIL_OWNER_TXT}New texts to translate in '#{text_resource.name}'"
    )
  end

  def resource_translation_complete(user, text_resource, languages, all_complete)
    @html_email = true
    @user = user
    @text_resource = text_resource
    @languages = languages
    @all_complete = all_complete

    mail(
      to: user.email_with_name,
      subject: "#{EMAIL_OWNER_TXT}Translation of '#{text_resource.name}' is complete"
    )
  end

  def comment_for_web_message(user, by_user, web_message, body)
    @user = user
    @by_user = by_user
    @web_message = web_message
    @body = body

    mail(
      to: user.email_with_name,
      subject: "#{EMAIL_OWNER_TXT}New comment on instant translation work"
    )
  end

  def assigned_translator(user, website_translation_contract, translator, still_open_pairs)
    pending_language_pairs = still_open_pairs.collect { |p| [p.from_language.nname, p.to_language.nname] }
    @user = user
    @website_translation_contract = website_translation_contract
    @website_translation_offer = website_translation_contract.website_translation_offer
    @website = website_translation_contract.website_translation_offer.website
    @translator = translator
    @pending_language_pairs = pending_language_pairs

    mail(
      to: user.email_with_name,
      subject: "#{EMAIL_OWNER_TXT}#{website_translation_contract.website_translation_offer.from_language.nname} -> #{website_translation_contract.website_translation_offer.to_language.nname} translator assigned to project '#{website_translation_contract.website_translation_offer.website.name}'"
    )
  end

  def assigning_translators_to_project(user, supporter, unassigned_offers, missing_translators)
    @user                = user
    @unassigned_offers   = unassigned_offers
    @missing_translators = missing_translators

    mail(
      to: supporter ? supporter.email_with_name : user.email_with_name,
      subject: "#{EMAIL_OWNER_TXT}Professional translation for your site"
    )
  end

  def missing_translators(supporter, user, offers_with_no_translators)
    @html_email = true
    @user = user
    @offers_with_no_translators = offers_with_no_translators

    mail(
      to: supporter.email_with_name,
      subject: "#{EMAIL_OWNER_TXT}Missing translators for new website translation"
    )
  end

  def translation_language_pending(admin, user, translator_language)
    @html_email = true
    @user = user
    @translator_language = translator_language

    mail(
      to: admin.email,
      subject: "#{EMAIL_OWNER_TXT}New translation language"
    )
  end

  def offer_help_with_hm(client)
    @html_email = true
    @user = client

    mail(
      to: client.email_with_name,
      from: NEWSLETTER_SENDER,
      subject: 'Need help with your H&M project translation?'
    )
  end

  def closed_offers_for_website(website, closed_offers)
    @html_email = true
    @user = website.client
    @website = website
    @closed_offers = closed_offers

    mail(
      to: website.client.email_with_name,
      subject: "#{EMAIL_OWNER_TXT}#{website.name} is now closed for translators"
    )
  end

  def invoice_paid(invoice)
    @html_email = true
    @user = invoice.user
    @invoice = invoice

    with_user_locale(@user) do
      mail(
        to: invoice.user.email_with_name,
        subject: EMAIL_OWNER_TXT + _('payment confirmation and invoice')
      )
    end
  end

  # --- reviewers ---

  def new_message_for_managed_work(user, managed_work, message)
    @html_email = true
    @user = user
    @managed_work = managed_work
    @message = message

    mail(
      to: user.email_with_name,
      subject: "#{EMAIL_OWNER_TXT}New message on project review"
    )
  end

  def managed_work_ready_for_review(user, managed_work, title, url_args)
    @html_email = true
    @user = user
    @managed_work = managed_work
    @title = title
    @url_args = url_args

    mail(
      to: user.email_with_name,
      subject: "#{EMAIL_OWNER_TXT}Translation complete - please review"
    )
  end

  def managed_work_complete(user, managed_work, to_language, title, url_args)
    @html_email = true
    @user = user
    @managed_work = managed_work
    @to_language = to_language
    @title = title
    @url_args = url_args

    mail(
      to: user.email_with_name,
      subject: "#{EMAIL_OWNER_TXT}Review complete"
    )
  end

  def new_issue(user, issue, message)
    @html_email = true
    @user = user
    @issue = issue
    @message = message

    mail(
      to: user.email_with_name,
      subject: "#{EMAIL_OWNER_TXT}New issue for your attention"
    )
  end

  def new_message_for_issue(user, issue, message)
    @html_email = true
    @user = user
    @issue = issue
    @message = message

    mail(
      to: user.email_with_name,
      subject: "#{EMAIL_OWNER_TXT}New message issue tracking"
    )
  end

  def issue_status_updated(user, issue)
    @html_email = true
    @user = user
    @issue = issue

    mail(
      to: user.email_with_name,
      subject: "#{EMAIL_OWNER_TXT}Issue status updated"
    )
  end

  def web_message_to_review(user, web_message)
    @html_email = true
    @user = user
    @web_message = web_message

    mail(
      to: user.email_with_name,
      subject: "#{EMAIL_OWNER_TXT}Instant Translation jobs for your review"
    )
  end

  def project_for_review(bid)
    @html_email = true
    @user              = bid.revision_language.managed_work.translator
    @chat              = bid.chat
    @managed_work      = bid.revision_language.managed_work
    @revision_language = bid.revision_language
    @revision          = bid.revision_language.revision
    @project           = bid.revision_language.revision.project

    mail(
      to: bid.revision_language.managed_work.translator.email_with_name,
      subject: "#{EMAIL_OWNER_TXT}Project ready for your review"
    )
  end

  def review_completed_for_project(user, reviewer, chat, revision_languages)
    @html_email = true
    @user               = user
    @reviewer           = reviewer
    @chat               = chat
    @revision_languages = revision_languages
    @revision           = chat.revision
    @project            = chat.revision.project

    mail(
      to: user.email_with_name,
      subject: "#{EMAIL_OWNER_TXT}Project ready for your review"
    )
  end

  def review_completed_for_cms_job(user, reviewer, chat, revision_languages, cms_request)
    @html_email = true
    @user               = user
    @reviewer           = reviewer
    @chat               = chat
    @revision_languages = revision_languages
    @revision           = chat.revision
    @project            = chat.revision.project
    @cms_request        = cms_request

    mail(
      to: user.email_with_name,
      subject: "#{EMAIL_OWNER_TXT}Document translated and reviewed"
    )
  end

  def notify_review_completed_with_open_issues(translator, reviewer, revision_language, cms_request)
    @html_email        = true
    @translator        = translator
    @reviewer          = reviewer
    @revision_language = revision_language
    @cms_request       = cms_request

    mail(
      to: translator.email_with_name,
      subject: "#{EMAIL_OWNER_TXT}Reviewer has opened issue"
    )
  end

  def cms_ready_for_review(reviewer, cms)
    @html_email = true
    @user = reviewer
    @cms = cms
    mail(to: reviewer.email_with_name, subject: "#{EMAIL_OWNER_TXT} CMS Job is ready for you to review")
  end

  def invite_to_cms(user, website_translation_contract, invitation, sample_text)
    @html_email = true
    @user                         = user
    @website_translation_contract = website_translation_contract
    @website_translation_offer    = website_translation_contract.website_translation_offer
    @website                      = website_translation_contract.website_translation_offer.website
    @invitation                   = invitation
    @sample_text                  = sample_text

    mail(
      to: user.email_with_name,
      subject: "#{EMAIL_OWNER_TXT}You are invited to apply to a project"
    )
  end

  def feedback_from_visitor(user, feedback)
    @user = user
    @feedback = feedback

    if feedback.owner.class == ResourceLanguage
      @job_url = { controller: :text_resources, action: :show, id: feedback.owner.text_resource.id }
    end

    mail(
      to: user.email_with_name,
      subject: "#{EMAIL_OWNER_TXT}Feedback about your translation"
    )
  end

  def new_keyword_project(translator, keyword_project)
    @translator = translator
    @keyword_project = keyword_project

    mail(
      to: translator.email,
      subject: "New keyword localization requested for #{keyword_project.owner.project.name}"
    )
  end

  def keyword_project_completed(project)
    @project = project

    mail(
      to: project.client.email,
      subject: "Keyword localization completed for #{project.name}"
    )
  end

  def no_translation_progress(name, email, website, from_language, to_language, days)
    @use_wpml_template = true
    @footer_translation_analytics = true

    ApplicationMailer.default_url_options[:host] = 'www.icanlocalize.com'
    analytics_language_pair = website.translation_analytics_language_pairs.find_by(from_language_id: from_language.id, to_language_id: to_language.id)
    deadline = analytics_language_pair.deadline.strftime('%Y-%m-%d')
    words = analytics_language_pair.translation_snapshots.last.untranslated_words
    @html_email = true

    @user_name = name
    @website = website
    @project = website.translation_analytics_profile.project
    @from_language = from_language
    @to_language = to_language
    @days_with_no_progress = days
    @create_language_pair_link = "#{EMAIL_LINK_PROTOCOL}#{EMAIL_LINK_HOST}/websites/#{website.id}/website_translation_offers/load_or_create_from_ta?wid=#{website.id}&accesskey=#{website.accesskey}&auto_setup=true&words=#{words}&deadline=#{deadline}&from_language_id=#{from_language.id}&to_language_id=#{to_language.id}"

    mail(
      to: email,
      subject: "Translation for #{website.name} is not progressing"
    )
  end

  def missed_translation_deadline(name, email, website, from_language, to_language, deadline, estimated_deadline)
    @use_wpml_template = true
    @footer_translation_analytics = true

    ApplicationMailer.default_url_options[:host] = 'www.icanlocalize.com'

    analytics_language_pair = website.translation_analytics_language_pairs.find_by(from_language_id: from_language.id, to_language_id: to_language.id)
    deadline = analytics_language_pair.deadline.strftime('%Y-%m-%d')
    words = analytics_language_pair.translation_snapshots.last.untranslated_words

    @html_email = true

    @user_name = name
    @website = website
    @project = website.translation_analytics_profile.project
    @from_language = from_language
    @to_language = to_language
    @estimated_deadline = estimated_deadline
    @set_deadline = deadline
    @create_language_pair_link = "#{EMAIL_LINK_PROTOCOL}#{EMAIL_LINK_HOST}/websites/#{website.id}/website_translation_offers/load_or_create_from_ta?wid=#{website.id}&accesskey=#{website.accesskey}&auto_setup=true&words=#{words}&deadline=#{deadline}&from_language_id=#{from_language.id}&to_language_id=#{to_language.id}"

    mail(
      to: email,
      subject: "Translation progress alert for #{website.name}"
    )
  end

  # Send e-mail to supporters about recently paid language pairs that require
  # "automatic" translator assignment.
  def auto_assign_needed(language_pairs)
    @language_pairs = language_pairs

    mail(
      to: CMS_SUPPORTER_EMAIL,
      subject: "Translator assignment required for #{language_pairs.size} language pairs."
    )
  end

  ################################ iclweb-42 ###################################
  ####################### Clients with No activity #############################
  # 1. Clients registered but did not start any project - 24 hours.
  def did_not_start_any_project(client)
    @client = client

    mail(
      to: client.email_with_name,
      subject: EMAIL_OWNER_TXT + _('Need help getting started?')
    )
  end

  # 2. Clients who registered and started a WP site project, but "Nothing was sent to translation in this project." and no languages selected. - 1-2 hours
  def wp_nothing_sent_to_translation(website)
    @html_email = true
    @client = website.client
    @website = website

    mail(
      to: client.email_with_name,
      subject: EMAIL_OWNER_TXT + _('Need help sending content for translation?')
    )
  end

  # 3. Clients who registered and started a WP site project, but did not select any translator from those who applied. - 24 hours (?)
  def wp_did_not_select_a_translator(website)
    @html_email = true
    @client = website.client
    @website = website

    mail(
      to: website.client.email_with_name,
      subject: EMAIL_OWNER_TXT + _('Need help getting started?')
    )
  end

  # 4. Clients who started a software/bidding project, but did not upload the file. - 2 hours
  def software_bidding_did_not_upload_files(client)
    @client = client

    mail(
      to: client.email_with_name,
      subject: EMAIL_OWNER_TXT + _('Need help getting started?')
    )
  end

  # 5. Clients who started a software/bidding project, but did not add languages. - 2 hours
  def software_bidding_did_not_language(project)
    @client = project.client
    @project = project

    mail(
      to: project.client.email_with_name,
      subject: EMAIL_OWNER_TXT + _('Need help getting started?')
    )
  end

  # 6. Clients who registered and started a software project, but did not accept
  #   translators who applied, and did not send strings to them, and did not add a deposit - 24 hours
  def software_did_not_accepted_translator_nor_send_string_nor_add_deposit(project)
    @client = project.client
    @project = project

    mail(
      to: project.client.email_with_name,
      subject: EMAIL_OWNER_TXT + _('Need help getting started?')
    )
  end

  # 7. Clients who started a bidding project, but did not accept translators who applied, and did not add a deposit.
  def bidding_not_accepted_translators(client)
    @client = client

    mail(
      to: client.email_with_name,
      subject: EMAIL_OWNER_TXT + _('Need help getting started?')
    )
  end

  # 8. Clients who started WP project, but did not add a deposit. - 24 hours
  def wp_not_deposited(website)
    @html_email = true
    @client = website.client
    @website = website

    mail(
      to: website.client.email_with_name,
      subject: EMAIL_OWNER_TXT + _('Need help getting started?')
    )
  end

  # 9. Clients who started a software project, accepted translators but didn’t send strings.
  def software_accepted_translators_no_strings(project)
    @client = project.client
    @project = project

    mail(
      to: project.client.email_with_name,
      subject: EMAIL_OWNER_TXT + _('Need help getting started?')
    )
  end

  # 10. Clients who started a software project, accepted translators, sent strings but didn’t pay.
  def software_has_strings_but_no_payment(project)
    @client = project.client
    @project = project

    mail(
      to: project.client.email_with_name,
      subject: EMAIL_OWNER_TXT + _('Need help with the translation of your software project?')
    )
  end

  ###############################################################

  def css_test(email)
    @html_email = true

    mail(to: email, subject: 'CSS test')
  end

  def timeout_error(params, exception, user)
    @params = params
    @user = user
    @exception = exception

    mail(
      to: 'icl-development@onthegosystems.com',
      subject: "Timeout error for #{params[:controller]}##{params[:action]}"
    )
  end

  def notify_translator_for_auto_assigned_project(website_translation_contract)
    @html_email = true
    @website_translation_contract = website_translation_contract
    @website_translation_offer = website_translation_contract.website_translation_offer
    @website = @website_translation_offer.website
    @translator = @website_translation_contract.translator
    mail(to: @website_translation_contract.translator.email, subject: "ICanLocalize assigned you to work on project #{@website.name.titleize}")
  end

  def notify_reviewer_for_auto_assigned_project(website_translation_offer)
    @html_email = true
    @website_translation_offer = website_translation_offer
    @website = @website_translation_offer.website
    @translator = website_translation_offer.managed_work.translator
    mail(to: @translator.email, subject: "ICanLocalize assigned you to review on project #{@website.name.titleize}")
  end

  def notify_client_for_auto_assigned_project(offer, contracts = [])
    @html_email = true
    @website_translation_offer = offer
    @website = @website_translation_offer.website
    @review_jobs = contracts.select { |x| x.class.name == 'ManagedWork' }
    @translate_jobs = contracts.select { |x| x.class.name == 'WebsiteTranslationContract' }
    @client = @website.client
    mail(to: @website.client.email, subject: "We’ve assigned translators and reviewers to your project #{@website.name.titleize}")
  end

  def unstarted_auto_assign_jobs(cms_requests)
    @grouped_cms_requests = cms_requests
    mail(to: CMS_SUPPORTER_EMAIL, subject: 'Unstarted auto-assignment translation jobs')
  end

  def job_has_base64_content(cms_request)
    @cms_request = cms_request
    @url = url_for(controller: 'cms_requests', action: 'show', website_id: @cms_request.website_id, id: @cms_request.id)
    mail(to: CMS_SUPPORTER_EMAIL, subject: 'CMS Job source XLIFF has base64 content')
  end

  def daily_completed_jobs_report(website, cms_requests)
    @website = website
    @client = website.client
    @cms_requests = cms_requests
    mail(to: @website.client.email_with_name, subject: 'Daily completed jobs summary')
  end

  private

  def truncate(str, max_length, replace)
    if str.length > (max_length - replace.length)
      str[0..(max_length - replace.length)] + replace
    else
      str
    end
  end

  # TODO: fix me
  def set_user_locale(user)
    @prev_locale = @locale
    if LOCALES.value?(user.loc_code)
      set_locale(user.loc_code)
    else
      set_locale(DEFAULT_LOCALE)
    end
  end

  def with_user_locale(_user)
    # set_user_locale(user)
    result = yield
    # No method set_locale
    # set_locale(@prev_locale)

    result
  end
end
