require 'net/imap'

class EmailChecker

  DEBUG = false
  EMAIL_REFS = { '20' => ' ',
                 '21' => '!',
                 '22' => '"',
                 '23' => '#',
                 '24' => '$',
                 '25' => '%',
                 '26' => '&',
                 '27' => "'",
                 '28' => '(',
                 '29' => ')',
                 '2a' => '*',
                 '2b' => '+',
                 '2c' => ',',
                 '2d' => '-',
                 '2e' => '.',
                 '2f' => '/',
                 '3a' => ':',
                 '3b' => ';',
                 '3c' => '<',
                 '3d' => '=',
                 '3e' => '>',
                 '3f' => '?',
                 '40' => '@',
                 '5b' => '[',
                 '5c' => '\\',
                 '5e' => '^',
                 '5f' => '_',
                 '60' => "'",
                 '7e' => '~' }.freeze

  def connect_to_imap(host)
    connection_attempts = 3
    begin
      imap = Net::IMAP.new(host, 993, true)
      return imap
    rescue SocketError, Errno::ENETUNREACH, Errno::ETIMEDOUT => e
      if (connection_attempts -= 1) > 0
        sleep 2
        retry
      else
        Rails.logger.info 'Unable to connect to the Gmail IMAP server to ' \
           'retrieve incoming e-mails. Maximum number of retries was reached. ' \
           "Error: #{e}"
        nil
      end
    end
  end

  def process_new_emails
    last_check = Option.get('last_email_checked', '1')
    # puts "ID: #{last_check.id}, value: #{last_check.value}"

    last_scanned_id = nil

    imap = connect_to_imap('imap.gmail.com')
    return unless imap
    imap.login(RAW_EMAIL_SENDER, RAW_EMAIL_PASSWORD)
    imap.select('INBOX')
    puts "Scanning messages: #{"#{last_check.value}:1000000"}"

    processed = 0

    imap.search(["#{last_check.value}:1000000"]).each do |message_id|
      last_scanned_id = message_id
      envelope = imap.fetch(message_id, 'ENVELOPE')[0].attr['ENVELOPE']
      subject = envelope.subject
      # email = envelope.from[0].email

      puts("checking email.#{message_id} - #{subject}")

      next if subject.blank?
      # check for web dialogs
      tkt = nil
      stk = nil

      x = subject.gsub(/\(TKT\:.*\)/) { |p| tkt = p[5..-2].to_i }
      x = subject.gsub(/\(STK\:.*\)/) { |p| stk = p[5..-2].to_i }

      if tkt && (tkt > 0)
        # puts "found ticket: #{tkt}"
        begin
          web_dialog = WebDialog.find(tkt)
        rescue
          next
        end
        raw_body = imap.fetch(message_id, 'BODY[TEXT]')[0].attr['BODY[TEXT]']
        # look for the accesskey value
        accesskey_txt = "accesskey=#{web_dialog.accesskey}"
        if raw_body && raw_body.index(accesskey_txt)

          body = clean_reply(raw_body)

          # if it's there, add the message to the dialog
          translation_status = if web_dialog.visitor_language_id == web_dialog.client_department.language_id
                                 TRANSLATION_NOT_NEEDED
                               else
                                 TRANSLATION_PENDING_CLIENT_REVIEW
                               end

          message = WebMessage.new(visitor_body: body,
                                   translation_status: translation_status,
                                   create_time: Time.now,
                                   comment: 'Part of a support ticket system, extracted from incoming email')

          message.associate_with_dialog(web_dialog, body)

          web_dialog.update_attributes!(status: SUPPORT_TICKET_WAITING_REPLY)

          # send the new message notification
          notify_client_about_new_message(web_dialog, message)

          processed += 1
        end
      elsif stk && (stk > 0)
        puts("found ticket: #{stk}") if DEBUG
        begin
          support_ticket = SupportTicket.find(stk)
        rescue
          next
        end

        user = support_ticket.normal_user

        reference = support_ticket.reference()
        puts("looking for reference: #{reference}") if DEBUG
        raw_body = imap.fetch(message_id, 'BODY[TEXT]')[0].attr['BODY[TEXT]']
        if raw_body && raw_body.index(reference)

          body = clean_reply(raw_body)

          puts("adding message:\n\n#{body}\n") if DEBUG

          message = Message.new(body: body, chgtime: Time.now)
          message.owner = support_ticket
          message.user = user

          Message.transaction do
            begin
              message.save!

              support_ticket.update_attributes!(status: SUPPORT_TICKET_WAITING_REPLY)

              # delete all existing reminders to the user
              delete_user_reminder_for_ticket(support_ticket, support_ticket.normal_user_id)

              admins = support_ticket.supporter ? [support_ticket.supporter] : Admin.all
              admins.each do |admin|
                if admin.can_receive_emails?
                  ReminderMailer.notify_support_about_ticket_update(admin, support_ticket).deliver_now
                end
              end
            rescue
            end
          end

          processed += 1
        end
      end

    end
    if last_scanned_id
      last_check.update_attributes!(value: (last_scanned_id + 1).to_s)
    end

    processed
  end

  def notify_client_about_new_message(web_dialog, message)
    deliver = false
    not_enough_money = false
    if [TRANSLATION_NOT_NEEDED, TRANSLATION_PENDING_CLIENT_REVIEW].include?(message.translation_status)
      deliver = true
    elsif (message.translation_status == TRANSLATION_NEEDED) && !message.has_enough_money_for_translation?
      deliver = true
      not_enough_money = true
    end
    if deliver
      if web_dialog.can_receive_emails?
        InstantMessageMailer.notify_client(web_dialog, message, not_enough_money).deliver_now
      end
    end
  end

  def delete_user_reminder_for_ticket(support_ticket, to_who_id)
    Reminder.where("owner_id= ? AND owner_type='SupportTicket' AND normal_user_id= ?", support_ticket.id, to_who_id).delete_all
  end

  def get_last_emails(base_idx, count)
    puts 'starting'
    imap = connect_to_imap('imap.gmail.com')
    return unless imap
    imap.login(RAW_EMAIL_SENDER, RAW_EMAIL_PASSWORD)
    imap.select('INBOX')
    puts 'connected o INBOX'
    # puts "Scanning messages: #{"#{last_check.value}:1000000"}"

    res = []

    imap.search(["#{base_idx}:#{base_idx + count}"]).each do |message_id|
      puts "got message #{message_id}"
      envelope = imap.fetch(message_id, 'ENVELOPE')[0].attr['ENVELOPE']
      subject = envelope.subject
      # email = envelope.from[0].email

      next if subject.blank?
      # check for web dialogs
      tkt = nil
      stk = nil

      x = subject.gsub(/\(TKT\:.*\)/) { |p| tkt = p[5..-2].to_i }
      x = subject.gsub(/\(STK\:.*\)/) { |p| stk = p[5..-2].to_i }

      if (tkt && (tkt > 0)) || (stk && (stk > 0))
        body = imap.fetch(message_id, 'BODY[TEXT]')[0].attr['BODY[TEXT]']
        res << [message_id, subject, unencode_chars(body)]
      end

    end

    puts "Last email scanned: #{message_id}"

    res
  end

  def clean_reply(txt)
    txt = unencode_chars(txt)
    txt = txt.tr("\r", "\n")
    txt = txt.gsub("\n\n", "\n")

    # remove everything after the original message
    original_idx = txt.index('Original Message')
    txt = txt[0...original_idx] if original_idx

    # remove the stuff before multipart messages
    mp_message = 'This is a multi-part message in MIME format.'
    multipart_idx = txt.index(mp_message)
    if multipart_idx
      te_message = 'Content-Transfer-Encoding:'
      te_idx = txt.index(te_message)
      if te_idx
        eol = txt.index("\n", te_idx)
        txt = txt[eol..-1] if eol
      end
    end

    # remove all lines begining with >
    lines = txt.split("\n")
    good_lines = []
    lines.each do |line|
      unless line.start_with?('>', 'To:', 'From:', 'Subject:', 'Date:', 'Sent:', '----')
        good_lines << line
      end
    end
    txt = good_lines.join("\n")

    txt

  end

  def unencode_chars(txt)
    txt.gsub(/(=[A-F0-9]{2})/) { |p| EMAIL_REFS[p[1..-1].downcase] || p }
  end

end
