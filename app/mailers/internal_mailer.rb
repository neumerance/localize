class InternalMailer < ApplicationMailer
  default from: EMAIL_SENDER

  def exception_report(exception, request = nil)
    @exception = exception
    @request = request

    mail(to: EMAILS_TO_RECEIVE_ERRORS,
         subject: "[#{Rails.env}] ICL Error: #{exception.class}")
  end

  def billing(subject, content, data = {})
    @subject = subject
    @content = content
    @data = data

    mail(from: "ICanLocalize Finance <#{RAW_EMAIL_SENDER}>",
         to: ['icl-development@onthegosystems.com', 'irina.s@onthegosystems.com', 'ornela.f@onthegosystems.com', 'valentina.v@onthegosystems.com'],
         subject: "#{Rails.env}: #{subject} #{Time.now.strftime('%s')}")
  end
end
