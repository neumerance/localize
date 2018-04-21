module Users
  module WelcomeMail
    def send_welcome(client)

      # check if this client came from Help and Manual
      begin
        hm_owner = Client.find(HM_CLIENT_ID)
      rescue
        hm_owner = nil
      end

      # check if this came through a known affiliate
      found_type = if hm_owner && (client.affiliate == hm_owner)
                     'hm'
                   else
                     find_user_source(client.source)
                   end

      subject = nil

      if client.can_receive_emails?
        ReminderMailer.welcome_site_user(client).deliver_now
      end

      if false
        name = nil
        supporter = nil

        # find the supporter who will send this ticket
        supporter_emails = [['laura.d@onthegosystems.com', 'Laura'], ['amir.helzer@onthegosystems.com', 'Amir']]
        supporter_emails.each do |supporter_email|
          supporter = User.where('email=?', supporter_email[0]).first
          if supporter
            name = supporter_email[1]
            break
          end
        end

        # make sure we found the supporter
        return unless supporter

        alternative_opening = "This is #{name} from ICanLocalize. I'd like to help you with your translation project.\n\n"

        body = "It looks like you're interested in #{what_to_do}.\n\n"
        body += "Have a look at this tutorial:\n#{guide_url}\n\n"
        body += "The tutorial includes step-by-step instructions and a short video.\n\n"
        body += 'In case you need any help, let me know. You can reply to this support ticket, or call +1-(702) 997-3025.'

        support_ticket = SupportTicket.new(subject: subject)
        support_ticket.normal_user = client
        support_ticket.supporter = supporter
        support_ticket.support_department = SupportDepartment.find_by(name: SUPPORTER_QUESTION)
        support_ticket.status = SUPPORT_TICKET_CREATED
        support_ticket.create_time = Time.new
        support_ticket.message = body
        support_ticket.save!

        message = Message.new(body: body)
        message.owner = support_ticket
        message.user = supporter
        message.chgtime = Time.now
        message.save!

        if support_ticket.normal_user.can_receive_emails?
          ReminderMailer.new_ticket_by_supporter(support_ticket, alternative_opening).deliver_now
        end
      end

      # this is for testing
      @sent_type = found_type

    end
  end
end
