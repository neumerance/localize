class ProcessEmailBounces
  prepend SimpleCommand

  def initialize(json)
    @json = json
  end

  def call
    recipients_to_blacklist = parse_notification
    blacklist_recipients(recipients_to_blacklist)
  end

  private

  # Returns a list of recipients to be blacklisted
  def parse_notification
    case @json['notificationType']
    when 'Bounce'
      parse_bounce
    when 'Complaint'
      parse_complaint
    else
      []
    end
  end

  def parse_bounce
    # https://docs.aws.amazon.com/ses/latest/DeveloperGuide/notification-contents.html#bounce-object
    recipients = @json['bounce']['bouncedRecipients'].map do |recipient|
      recipient['emailAddress']
    end.compact

    case @json['bounce']['bounceType']
    when 'Transient'
      Rails.logger.info("BouncesController - Soft bounces occurred for #{recipients.to_sentence}")
      # Do not blacklist on soft bounce
      return []
    when 'Permanent'
      Rails.logger.info("BouncesController - Hard bounces occurred for #{recipients.to_sentence}")
      return recipients
    end
  end

  def parse_complaint
    # https://docs.aws.amazon.com/ses/latest/DeveloperGuide/notification-contents.html#complaint-object
    # If e-mails is sent to more than one recipient, in most cases there is no
    # way to know which of them made the complaint and all will be blacklisted.
    # Bottom line, always send one e-mail per recipient.
    recipients = @json['complaint']['complainedRecipients'].map { |r| r['emailAddress'] }
    Rails.logger.info("BouncesController - Received SPAM complaint from #{recipients.to_sentence}")
    recipients
  end

  def blacklist_recipients(recipients)
    %w(User WebDialog AlertEmail).each do |model_name|
      records = model_name.constantize.where(email: recipients)
      records.update_all(bounced: true)
    end
  end
end
