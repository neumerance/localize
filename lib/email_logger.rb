# Log all outgoing e-mails
module EmailLogger
  def self.included(mailer)
    mailer.class_eval do
      after_action :log_email

      private

      def log_email
        Logging.log(self, "sent email: #{log_email_hash}") if email_was_sent?
      end

      def email_was_sent?
        to_email.present?
      end

      def to_email
        Array(headers.to).first
      end

      def log_email_hash
        {
          mailer_action: "#{self.class.name}##{action_name}",
          to: to_email,
          subject: headers.subject
        }
      end
    end
  end
end
