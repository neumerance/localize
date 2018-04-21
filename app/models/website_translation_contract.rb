#   status:
#         0: Translator did not apply
#         1: Translator applied
#         2: Application accepted
#         3: Application declined
class WebsiteTranslationContract < ApplicationRecord
  belongs_to :website_translation_offer
  belongs_to :translator, touch: true
  belongs_to :currency
  has_many :messages, as: :owner, dependent: :destroy
  has_many :reminders, as: :owner, dependent: :destroy

  validates :translator_id, uniqueness: {
    scope: :website_translation_offer_id,
    message: 'can only have one WebsiteTranslationContract per language pair per website.'
  }

  TRANSLATION_CONTRACT_DESCRIPTION = { TRANSLATION_CONTRACT_NOT_REQUESTED => N_('Translator did not apply'),
                                       TRANSLATION_CONTRACT_REQUESTED => N_('Translator applied'),
                                       TRANSLATION_CONTRACT_ACCEPTED => N_('Application accepted'),
                                       TRANSLATION_CONTRACT_DECLINED => N_('Application declined') }.freeze

  delegate :website, to: :website_translation_offer

  before_save :track_status_changes, if: -> { attribute_changed?(:status) }

  def display_payment(user)
    _('%.2f %s per word') % [amount, user ? currency.disp_name : currency.name]
  end

  def new_messages(user)
    if user
      messages.where('(is_new = 1) AND (user_id != ?)', user.id)
    else
      messages.where('(is_new = 1)')
    end
  end

  def add_message(from, to_who, params)
    message = Message.new(body: params[:body], chgtime: Time.now)
    message.user = from
    message.owner = self

    if message.valid?
      message.save!

      Reminder.where('(owner_type=?) AND (owner_id=?) AND (normal_user_id= ?)', self.class.to_s, id, from.id).destroy_all

      to_who.each do |user|
        if user.can_receive_emails?
          ReminderMailer.new_message_for_cms_translation(user, self, message).deliver_now
        end

        message_delivery = MessageDelivery.new
        message_delivery.user = user
        message_delivery.message = message
        message_delivery.save

        if %w(Client Translator).include?(user[:type])
          user.create_reminder(EVENT_NEW_WEBSITE_TRANSLATION_MESSAGE, self)
        end
      end

      create_attachments_for_message(message, params)
      save
    end
    message
  end

  def hours_since_assignment(cms_request)
    return nil if self.accepted_by_client_at.blank?
    [cms_request.created_at, self.accepted_by_client_at].max
  end

  class << self
    def resign_all_website_contract(user, website, remarks = '')
      has_on_going_job = user.has_on_going_cms_jobs(website)
      raise 'You are not allowed to resign from this website as you have already started a job on it' if has_on_going_job
      raise 'You do not translate this website' unless user.is_translator? || user.has_supporter_privileges?
      contracts = website.website_translation_contracts.where(translator: user, status: [TRANSLATION_CONTRACT_NOT_REQUESTED, TRANSLATION_CONTRACT_REQUESTED, TRANSLATION_CONTRACT_ACCEPTED])
      if contracts.present?
        contracts.update_all(status: TRANSLATION_CONTRACT_DECLINED)
        TranslatorsRefusedProject.refuse_project(website, user, 'translate', remarks) if user.is_a?(Translator)
      end
    end
  end

  private

  # Copied from ChatFunctions
  def create_attachments_for_message(message, params_to_use)
    attachment_id = 1
    cont = true
    attached = false
    while cont
      attached_data = params_to_use["file#{attachment_id}"]
      if !attached_data.blank? && !attached_data[:uploaded_data].blank?
        attachment = Attachment.new(attached_data)
        attachment.message = message
        attachment.save
        attachment_id += 1
        attached = true
      else
        cont = false
      end
    end
    message.reload if attached
  end

  def track_status_changes
    _, new_value = attribute_change(:status)

    if new_value == TRANSLATION_CONTRACT_ACCEPTED
      # Client has just accepted an application/bid from a translator
      self.accepted_by_client_at = Time.now
    end
  end
end
