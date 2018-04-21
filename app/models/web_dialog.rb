class WebDialog < ApplicationRecord
  serialize :complex_flag
  if Rails.env.production?
    acts_as_ferret(fields: [:client_subject, :visitor_subject],
                   index_dir: "#{FERRET_INDEX_DIR}/web_dialog",
                   remote: true)
  end

  attr_accessor :message

  validates_format_of :email, with: /\A([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})\z/i
  validates :fname, alpha_numeric: true
  validates :lname, alpha_numeric: true
  validates_presence_of :visitor_subject, :client_department_id, :email, :fname, :lname, :visitor_language_id
  has_many :web_messages, as: :owner, dependent: :destroy
  has_many :dialog_parameters

  belongs_to :client_department

  belongs_to :visitor_language, class_name: 'Language', foreign_key: :visitor_language_id

  has_one :text_resource, as: :owner

  STATUS_TEXT = { SUPPORT_TICKET_CREATED => N_('New ticket'),
                  SUPPORT_TICKET_ANSWERED => N_('Reply received'),
                  SUPPORT_TICKET_WAITING_REPLY => N_('Waiting for reply'),
                  SUPPORT_TICKET_SOLVED => N_('Ticket closed - problem solved'),
                  SUPPORT_TICKET_SOLVED => N_('Ticket closed - user never answered') }.freeze

  validate :validate_message_on_create, on: :create

  def validate_message_on_create
    errors.add(:message, "can't be blank") if message.blank?
  end

  def show_status
    STATUS_TEXT[status]
  end

  def full_name
    fname.capitalize + ' ' + lname.capitalize
  end

  def subject_for_user(user)
    user && (client_department.web_support.client == user) && !client_subject.blank? ? client_subject : visitor_subject
  end

  def user_can_close?(user)
    user && (client_department.web_support.client == user) &&
      [SUPPORT_TICKET_CREATED, SUPPORT_TICKET_WAITING_REPLY].include?(status)
  end

  def available_web_messages_for_user(user)
    if user && (client_department.web_support.client == user)
      web_messages
    else
      web_messages.where('(visitor_body IS NOT NULL) OR (translation_status=?)', TRANSLATION_NOT_NEEDED)
    end
  end

  def is_first_message(message)
    (web_messages.count == 0) || (web_messages[0] == message)
  end

  def text_to_translate
    visitor_subject
  end

  def email_with_name
    "#{fname.capitalize} #{lname.capitalize} <#{email}>"
  end

  def optional_accesskey(user)
    user ? nil : accesskey
  end

  def email_track_code
    "(TKT:#{id})"
  end

  def can_receive_emails?
    !bounced
  end
end
