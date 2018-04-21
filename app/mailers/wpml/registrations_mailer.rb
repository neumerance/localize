class Wpml::RegistrationsMailer < ApplicationMailer

  layout :choose_layout

  def welcome(user)
    @html_email = true
    @user = user
    mail(
      from: EMAIL_SENDER,
      to: user.email_with_name,
      subject: 'Your new ICanLocalize account'
    )
  end

  private

  def choose_layout
    @use_wpml_template ? 'wpml_email' : 'email'
  end

end
