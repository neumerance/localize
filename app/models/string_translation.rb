#   status:
#     STRING_TRANSLATION_COMPLETE = 0
#     STRING_TRANSLATION_NEEDS_UPDATE = 1
#     STRING_TRANSLATION_BEING_TRANSLATED = 2 (paid, translators should owrk on it)
#     STRING_TRANSLATION_MISSING = 3 (Missing funds)
#     STRING_TRANSLATION_DUPLICATE = 4
#
#   review_status:
#     REVIEW_NOT_NEEDED = 0               # client didn't pay for a review
#     REVIEW_PENDING_ALREADY_FUNDED = 1   # translator completed translation, time for review (funded)
#     REVIEW_COMPLETED = 2                # review is completed
#     REVIEW_AFTER_TRANSLATION = 3        # client paid for review. need to translate first
#
#   pay_translator
#     0 = translation is already paid, no need to pay
#     1 = translation have to be paid
class StringTranslation < ApplicationRecord

  include LengthCounter

  belongs_to :resource_string, touch: true
  has_one :text_resource, through: :resource_string
  belongs_to :language
  belongs_to :last_editor, class_name: 'User', foreign_key: :last_editor_id

  has_one :money_transaction, as: :owner, dependent: :destroy

  has_many :issues, as: :owner, dependent: :destroy

  has_one :tu, as: :owner, dependent: :destroy

  before_save :set_size_ratio
  after_save :touch_text_resource

  validates :txt, length: { maximum: COMMON_NOTE }

  STATUS_TEXT = { STRING_TRANSLATION_COMPLETE => N_('Translation complete'),
                  STRING_TRANSLATION_NEEDS_UPDATE => N_('Translation needs update'),
                  STRING_TRANSLATION_BEING_TRANSLATED => N_('Translation assigned to translator'),
                  STRING_TRANSLATION_MISSING => N_('Translation missing'),
                  STRING_TRANSLATION_DUPLICATE => N_('Duplicate string'),
                  STRING_TRANSLATION_NEEDS_REVIEW => N_('Waiting for review') }.freeze

  TRANSLATOR_STATUS_TEXT = {  STRING_TRANSLATION_COMPLETE => N_('Translation complete'),
                              STRING_TRANSLATION_NEEDS_UPDATE => N_('Client did not yet send this text to translation'),
                              STRING_TRANSLATION_BEING_TRANSLATED => N_('This text needs to be translated'),
                              STRING_TRANSLATION_MISSING => N_('Client did not yet send this text to translation'),
                              STRING_TRANSLATION_DUPLICATE => N_('Duplicate text. Only the original needs to be translated.'),
                              STRING_TRANSLATION_NEEDS_REVIEW => N_('Waiting for review') }.freeze

  TRANSLATION_COLOR_CODE = {  STRING_TRANSLATION_COMPLETE => '#FFFFFF',
                              STRING_TRANSLATION_NEEDS_UPDATE => '#FFE0E0',
                              STRING_TRANSLATION_BEING_TRANSLATED => '#E0E0FF',
                              STRING_TRANSLATION_MISSING => '#FFE0E0',
                              STRING_TRANSLATION_DUPLICATE => '#FFFFFF',
                              STRING_TRANSLATION_NEEDS_REVIEW => '#F0E0FF' }.freeze

  def resource_language
    if text_resource
      text_resource.resource_languages.find_by(language_id: language.id)
    end
  end

  # To avoid repetitive queries is posisble to send the resource string as parameter
  def txt(res_string = false)
    res_string ||= resource_string

    if self['txt'].blank? && res_string && res_string.master_string
      res_string.master_string.string_translations.find_by(language_id: language_id).txt
    else
      self['txt']
    end
  end

  def set_size_ratio
    100
    # Removed as Amir requested,
    #   https://onthegosystems.myjetbrains.com/youtrack/issue/icls-51
    #     if !txt.blank?
    #       txt.strip!
    #     end
    #
    #     if resource_string.txt.blank?
    #       ratio = nil
    #     elsif txt.blank?
    #       ratio = 0
    #     else
    #       ratio = txt_length.to_f / resource_string.txt_length.to_f
    #     end
    #
    #     self.size_ratio = ratio
  end

  def add_to_tm
    return if status == STRING_TRANSLATION_DUPLICATE

    signature = Digest::MD5.hexdigest(resource_string.txt)

    other_tu = Tu.where(
      '(client_id=?) AND (signature=?) AND (from_language_id=?) AND (to_language_id=?)',
      resource_string.text_resource.client.id,
      signature,
      resource_string.text_resource.language_id,
      language.id
    ).first

    if other_tu
      other_tu.translator = last_editor.try(:[], :type) == 'Translator' ? last_editor : nil
      other_tu.update_attributes(translation: txt)
    else
      tu = Tu.new(original: resource_string.txt,
                  translation: txt,
                  signature: signature,
                  from_language_id: resource_string.text_resource.language_id, to_language_id: language.id,
                  status: status == STRING_TRANSLATION_COMPLETE ? TU_COMPLETE : TU_INCOMPLETE)
      tu.client = resource_string.text_resource.client
      tu.translator = last_editor.try(:[], :type) == 'Translator' ? last_editor : nil
      tu.owner = self
      tu.save
    end
  end

  def argument_match?
    return true if txt.nil?
    my_pos = required_text_position
    orig_pos = required_text_position(resource_string.txt)

    return false if my_pos.length != orig_pos.length

    for idx in (0...my_pos.length)
      return false if my_pos[idx] != orig_pos[idx]
    end

    true
  end

  def touch_text_resource
    self.text_resource.touch
  end

  def get_client_id
    resource_string.text_resource.client_id
  end

  def refund
    return false unless status == STRING_TRANSLATION_BEING_TRANSLATED

    words = resource_string.valid_word_count
    amount = words * resource_language.translation_amount

    resource_language_account = resource_language.money_accounts.first

    if resource_language_account.balance <= amount
      Rails.logger.error 'Not enough balance in resource_language account to ' \
        "refund string translation #{id}. Tried to refund #{amount} but the " \
        "resource_language account balance was #{resource_language_account.balance}."
      return false
    end

    # Should we refund review?
    # If refunded was done from use existing translations client may be interested
    # in keep review moving forward. If the refund comes from a delete action
    # review have to be refunded
    # if review_status == REVIEW_AFTER_TRANSLATION
    #  amount = amount + (words * resource_language.review_amount)
    # end
    transaction do
      MoneyTransactionProcessor.transfer_money(
        resource_language_account,
        text_resource.client.money_account,
        amount,
        DEFAULT_CURRENCY_ID,
        TRANSFER_REFUND_FOR_RESOURCE_TRANSLATION
      )

      self.status = STRING_TRANSLATION_MISSING
      self.save

      resource_language.update_word_count
    end
  end

  def refund_review
    return false unless [REVIEW_PENDING_ALREADY_FUNDED, REVIEW_AFTER_TRANSLATION].include? review_status

    words = resource_string.valid_word_count
    amount = words * resource_language.review_amount

    transaction do
      MoneyTransactionProcessor.transfer_money(
        resource_language.money_accounts.first,
        text_resource.client.money_account,
        amount,
        DEFAULT_CURRENCY_ID,
        TRANSFER_REFUND_FOR_RESOURCE_TRANSLATION
      )

      self.review_status = REVIEW_NOT_NEEDED
      self.save
    end
  end

  def check_enough_funds_for_review
    language_account = resource_language.find_or_create_account(DEFAULT_CURRENCY_ID)
    has_enough_balance = (language_account.balance + 0.01) >= resource_string.word_count * resource_language.review_amount

    unless has_enough_balance
      if review_status == REVIEW_PENDING_ALREADY_FUNDED
        self.update_attribute :review_status, REVIEW_NOT_NEEDED
        Rails.logger.info(" *** The escrow account for this resource language don't have enough funds for review, returning string to missing funds status *** ")
      end
    end
  end
end
