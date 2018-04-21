#   status:
#     RESOURCE_CHAT_NOT_APPLIED = 0
#     RESOURCE_CHAT_APPLIED = 1
#     RESOURCE_CHAT_ACCEPTED = 2
#     RESOURCE_CHAT_DECLINED = 3
#
#   translation_status:
#     RESOURCE_CHAT_NOTHING_TO_TRANSLATE = 1
#     RESOURCE_CHAT_PENDING_TRANSLATION = 2
#     RESOURCE_CHAT_TRANSLATION_COMPLETE = 3 # Reviewer needs to review
#     RESOURCE_CHAT_TRANSLATOR_NEEDS_TO_REVIEW = 5 # Review will be performed by translator
#     RESOURCE_CHAT_TRANSLATION_REVIEWED = 4
#
#   word_count: Amount of words that are already funded

class ResourceChat < ApplicationRecord
  belongs_to :translator, touch: true
  belongs_to :resource_language
  belongs_to :alias

  has_many :messages, as: :owner, dependent: :destroy
  has_one :support_ticket, as: :object

  STATUS_TEXT = { RESOURCE_CHAT_NOT_APPLIED => N_('Translator did not apply'),
                  RESOURCE_CHAT_APPLIED => N_('Translator applied'),
                  RESOURCE_CHAT_ACCEPTED => N_('Application accepted'),
                  RESOURCE_CHAT_DECLINED => N_('Application declined') }.freeze

  def accept
    resource_language.update_attributes(status: RESOURCE_LANGUAGE_CLOSED)
    if translator.can_receive_emails?
      ReminderMailer.accepted_application_for_resource_translation(translator, self).deliver_now
    end
    other_chats = resource_language.resource_chats.where('(resource_chats.id != ?) AND (resource_chats.status = ?)', id, RESOURCE_CHAT_APPLIED)
    other_chats.each do |c|
      c.update_attributes(status: RESOURCE_CHAT_DECLINED)
      if c.translator.can_receive_emails?
        ReminderMailer.other_application_accepted(c.translator, c).deliver_now
      end
    end
    update_attributes(status: RESOURCE_CHAT_ACCEPTED, translation_status: RESOURCE_CHAT_NOTHING_TO_TRANSLATE)
  end

  def cached_translation_strings(text_resource, untranslated_strings)
    conds = ['string_translations.language_id = ?']
    cond_args = [resource_language.language_id]
    if untranslated_strings.any?
      conds << 'string_translations.resource_string_id IN (?)'
      cond_args << untranslated_strings.pluck(:id)
    end
    condition = [conds.join(' AND ')] + cond_args
    translations = {}
    # prefetch all the translations, so that we don't need to go through each one as a DB query
    text_resource.string_translations.where(condition).find_each do |string_translation|
      translations[string_translation.resource_string_id] = string_translation
    end
    translations
  end

  def send_strings_to_translation(text_resource, untranslated_strings, _limit_amount, review_enabled)

    new_word_count = 0
    asian_language = Language.asian_language_ids.include?(text_resource.language.id)

    review_status = review_enabled ? REVIEW_AFTER_TRANSLATION : REVIEW_NOT_NEEDED

    translations = cached_translation_strings(text_resource, untranslated_strings)

    per_word_cost = translation_amount
    per_word_cost += resource_language.review_amount if review_enabled

    # now, set up each string for translation
    untranslated_strings.each do |resource_string|

      string_wc = asian_language ? (resource_string.txt.length / UTF8_ASIAN_WORDS).ceil : resource_string.txt.sanitized_split.length

      new_word_count += string_wc

      # check if translation already exists
      translation = translations[resource_string.id]

      if translation
        translation.update_attributes(status: STRING_TRANSLATION_BEING_TRANSLATED, pay_translator: 1, review_status: review_status, pay_reviewer: 1)
      else
        translation = StringTranslation.new(txt: resource_string.txt, status: STRING_TRANSLATION_BEING_TRANSLATED, pay_translator: 1, review_status: review_status, pay_reviewer: 1)
        translation.language = resource_language.language
        translation.resource_string = resource_string
        translation.save
      end

    end

    # initialize the word count if it was never set
    self.word_count = 0 if word_count.blank?

    msg = _('Strings sent to translation')

    self.word_count = 0 if word_count < 0

    self.word_count += new_word_count

    # set the deadline
    completion_time = (self.word_count / 300.0).ceil + 3
    self.deadline = Time.now + completion_time * DAY_IN_SECONDS

    save!
    reload

    # force the software localization display to update (invalidate the statistics cache)
    resource_language.update_version_num

    if new_word_count > 0
      if translator.can_receive_emails?
        ReminderMailer.new_strings_in_resource(translator, resource_language.text_resource, untranslated_strings.length, new_word_count, deadline).deliver_now
      end
    end

    # update translation status
    update_attributes!(translation_status: RESOURCE_CHAT_PENDING_TRANSLATION)

  end

  def send_strings_to_review(text_resource, resource_language, untranslated_strings, limit_amount)

    new_word_count = 0
    asian_language = Language.asian_language_ids.include?(text_resource.language.id)

    translations = cached_translation_strings(text_resource, untranslated_strings)

    per_word_cost = resource_language.review_amount

    # now, set up each string for translation
    untranslated_strings.each do |resource_string|

      string_wc = asian_language ? (resource_string.txt.length / UTF8_ASIAN_WORDS).ceil : resource_string.txt.sanitized_split.length

      # don't send to translation more strings than paid for
      if ((new_word_count + string_wc) * per_word_cost) > (limit_amount + 0.01)
        break
      else
        new_word_count += string_wc

        # check if translation already exists
        translation = translations[resource_string.id]

        if translation
          review_status = translation.status == STRING_TRANSLATION_COMPLETE ? REVIEW_PENDING_ALREADY_FUNDED : REVIEW_AFTER_TRANSLATION
          translation.update_attributes(review_status: review_status, pay_reviewer: 1)
        end
      end

    end

    msg = _('Strings sent to translation')

    # force the software localization display to update (invalidate the statistics cache)
    resource_language.update_version_num

    if (new_word_count > 0) && resource_language.managed_work
      if resource_language.managed_work.translator && (resource_language.managed_work.active == MANAGED_WORK_ACTIVE)
        resource_language.managed_work.update_attributes(translation_status: MANAGED_WORK_REVIEWING)
        if resource_language.managed_work.translator.can_receive_emails?
          ReminderMailer.managed_work_ready_for_review(resource_language.managed_work.translator, resource_language.managed_work,
                                                       'software localization project - %s' % resource_language.text_resource.name, controller: :text_resources, action: :show, id: resource_language.text_resource.id).deliver_now
        end
      else
        resource_language.managed_work.update_attributes(translation_status: MANAGED_WORK_WAITING_FOR_REVIEWER)
      end
    end

  end

  def is_late?
    (word_count > 0) && (deadline < Time.now)
  end

  def real_word_count
    # get all the untranslated texts in this language
    text_resource = resource_language.text_resource
    resource_strings =
      text_resource.resource_strings.
      joins(:string_translations).
      where(
        '(string_translations.language_id=?) AND (string_translations.status=?) AND (resource_strings.master_string_id IS NULL)',
        resource_language.language_id,
        STRING_TRANSLATION_BEING_TRANSLATED
      )

    current_word_count = text_resource.count_words(resource_strings, text_resource.language, resource_language)

    current_word_count
  end

  # Find inaccurate word counts
  def self.find_all_problems(print = false)
    res = []
    ResourceChat.where(['status=?', RESOURCE_CHAT_ACCEPTED]).find_each do |rc|
      res << rc if rc.word_count != rc.real_word_count
    end
    if print
      res.each { |rc| puts "rc.#{rc.id}: word_count=#{rc.word_count}, real_word_count=#{rc.real_word_count}" }
    else
      return res
    end
  end

  def need_to_declare_as_complete
    return false if translation_status != RESOURCE_CHAT_PENDING_TRANSLATION

    # check that nothing is being translated
    !resource_language.text_resource.resource_strings.joins(:string_translations).
      where(
        '(resource_strings.master_string_id IS NULL) AND (string_translations.language_id=?) AND (string_translations.status=?)',
        resource_language.language_id,
        STRING_TRANSLATION_BEING_TRANSLATED
      ).first
  end

  def translation_amount
    translator.userstatus == USER_STATUS_PRIVATE_TRANSLATOR ? 0 : resource_language.translation_amount
  end

  def create_message(user, params)
    message = Message.new(body: params[:body], chgtime: Time.now)
    message.user = user
    message.owner = self
    if message.valid?
      message.save!

      if user.is_a? Alias
        update_attribute :alias_id, user.id
      elsif user.instance_of? Client
        update_attribute :alias_id, nil
      end

      create_attachments_for_message(message, params)

      user.delete_reminder(self)
    end
    message
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

end
