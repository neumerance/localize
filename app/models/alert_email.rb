class AlertEmail < ApplicationRecord
  belongs_to :translation_analytics_profile

  validates_presence_of :name
  validates_presence_of :email
  validates_format_of :email, with: /\A([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})\z/i

  def can_receive_emails?
    !bounced && !(email =~ /unreg\d+@icanlocalize.com/)
  end
end
