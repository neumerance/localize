class SupportTicket < ApplicationRecord
  belongs_to :normal_user, foreign_key: :normal_user_id, class_name: 'User'
  belongs_to :supporter, foreign_key: :supporter_id, class_name: 'User'
  belongs_to :support_department
  belongs_to :object, polymorphic: true

  attr_accessor :message, :wp_username, :wp_password, :wp_login_url
  validates_presence_of :subject, :support_department
  validates :wp_login_url, url_field: true

  has_many :messages, as: :owner, dependent: :destroy
  has_many :reminders, as: :owner, dependent: :destroy

  STATUS_TEXT = { SUPPORT_TICKET_CREATED => N_('New ticket'),
                  SUPPORT_TICKET_ANSWERED => N_('Reply received'),
                  SUPPORT_TICKET_WAITING_REPLY => N_('Waiting for reply'),
                  SUPPORT_TICKET_SOLVED => N_('Ticket closed - problem solved'),
                  SUPPORT_TICKET_CLOSED => N_('Ticket closed - user never answered'),
                  SUPPORT_TICKET_INITIATED_BY_SUPPORTER => N_('Initiated by supporter') }.freeze

  validate :validate_message_on_create, on: :create

  before_create :encode_subject_emojis
  def encode_subject_emojis
    self.subject = Rumoji.encode subject
  end

  def subject_with_emojis
    Rumoji.decode subject
  end

  def validate_message_on_create
    errors.add(:message, "can't be blank") if message.blank?
  end

  def show_supporter
    if supporter
      supporter.full_name + ' <span class="comment">Only the assigned supporter receives email notifications for this ticket</span>'
    else
      'not yet assigned to a supporter <span class="comment">All supporters receive email notifications for this ticket</span>'
    end.html_safe
  end

  def show_status
    STATUS_TEXT[status]
  end

  def email_track_code
    "(STK:#{id})"
  end

  def reference
    "Reference:#{Digest::MD5.hexdigest(id.to_s + 'alskdj8cz333k')}"
  end

  def last_message_by_user(user)
    message = messages.order('ID desc').first
    message.user == user
  end

  def has_wp_credentials?
    wp_username.present? || wp_password.present? || wp_login_url.present?
  end
end
