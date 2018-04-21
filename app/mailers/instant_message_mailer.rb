class InstantMessageMailer < ApplicationMailer
  helper :application
  layout 'email'
  default from: EMAIL_SENDER

  def confirm(web_dialog, language)
    @html_email = true
    @web_dialog = web_dialog
    @signature = "#{web_dialog.client_department.web_support.name} - #{web_dialog.client_department.translated_name(language)}"

    mail(
      from: "#{web_dialog.client_department.web_support.name} - #{web_dialog.client_department.translated_name(language)} <#{RAW_EMAIL_SENDER}>",
      to:      web_dialog.email_with_name,
      subject: truncate(_('Re:') + ' ' + web_dialog.email_track_code + ' ' + web_dialog.visitor_subject, 60, '...')
    )
  end

  def flagged_as_complex(web_message)
    @html_email = true
    ActionMailer::Base.default_url_options[:host] = 'www.icanlocalize.com'
    @web_message = web_message
    @client = web_message.owner

    mail(
      to:      web_message.owner.email_with_name,
      subject: truncate("Project #{web_message.name} was flagged as complex", 60, '...')
    )
  end

  def notify_visitor(web_dialog, web_message, language)
    @html_email = true
    @web_dialog = web_dialog
    @web_message = web_message
    @has_attachments = !web_message.web_attachments.empty?

    sender_name = web_dialog.client_department.web_support.client.fname.capitalize
    @sender_name = sender_name
    @signature = "#{sender_name}\n#{web_dialog.client_department.web_support.name} - #{web_dialog.client_department.translated_name(language)}"

    mail(
      from: "#{web_dialog.client_department.web_support.name} - #{web_dialog.client_department.translated_name(language)} <#{RAW_EMAIL_SENDER}>",
      to:  web_dialog.email_with_name,
      subject: truncate(_('Re:') + ' ' + web_dialog.email_track_code + ' ' + web_dialog.visitor_subject, 60, '...')
    )
  end

  def notify_client(web_dialog, web_message, insufficient_funds)
    @html_email = true
    dialog = web_dialog.is_first_message(web_message) ? '' : _('Re:') + ' '
    @web_dialog = web_dialog
    @web_message = web_message
    @client = web_dialog.client_department.web_support.client
    @insufficient_funds = insufficient_funds
    @parameters = web_dialog.dialog_parameters.collect { |param| [param.name, param.value] }

    mail(
      from: "#{web_dialog.client_department.web_support.name} - #{web_dialog.client_department.name} <#{RAW_EMAIL_SENDER}>",
      to:  web_dialog.client_department.web_support.client.email_with_name,
      subject: truncate(dialog + web_dialog.subject_for_user(web_dialog.client_department.web_support.client), 60, '...')
    )
  end

  def instant_translation_complete(web_message)
    @html_email = true
    review = web_message.managed_work && (web_message.managed_work.active == MANAGED_WORK_ACTIVE)

    subject =
      if review
        _('Your instant translation project is translated')
      else
        _('Your instant translation project is complete')
      end

    @web_message = web_message
    @client = web_message.owner
    @review = review

    mail(
      to:  web_message.owner.email_with_name,
      subject: subject
    )
  end

  def instant_translation_reviewed(web_message)
    @html_email = true
    @web_message = web_message
    @client = web_message.owner

    mail(
      to:  web_message.owner.email_with_name,
      subject: _('Your instant translation project is complete')
    )
  end

  def truncate(str, max_length, replace)
    if str.length > (max_length - replace.length)
      str[0..(max_length - replace.length)] + replace
    else
      str
    end
  end

  def notify_alias_password_changed(user, password)
    @html_email = true
    @user = user
    @password = password
    mail(
      to:  @user.email,
      subject: _('Your password has been changed.')
    )
  end

  def notify_master_alias_password_changed(user, password)
    @html_email = true
    @user = user
    @password = password
    mail(
      to:  @user.master_account.email,
      subject: _('You have changed %s %s\'s password.' % [user.fname.titleize, user.lname.titleize])
    )
  end
end
