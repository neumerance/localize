DEBUG_SUBJECT = 'test ticket for emails'.freeze

user = User.where('email=?', 'orit@onthegosoft.com').first
supported = User.where('email=?', 'amir.helzer@onthegosystems.com').first

ticket = SupportTicket.where('subject=?', DEBUG_SUBJECT).first
unless ticket
  ticket = SupportTicket.new(subject: DEBUG_SUBJECT, normal_user_id: user.id, supporter_id: supported.id, support_department_id: 1, status: SUPPORT_TICKET_CREATED, create_time: Time.now, message: 'something')
  ticket.save!
end

e = EmailChecker.new
emails = e.get_last_emails(2000, 100)

emails.each do |email|
  email_num = email[0]
  email_title = email[1]
  email_contents = email[2]
  dump = File.new("#{Rails.root}/log/emails/email_#{email_num}.txt", 'w')
  dump.write("Subject: #{email_title}\n\nBody:\n#{email_contents}")
  dump.close

  message = Message.new(body: email_contents, chgtime: Time.now)
  message.user = user
  message.owner = ticket
  message.save!
end
