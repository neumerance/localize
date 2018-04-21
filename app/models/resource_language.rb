#   status:
#       0: RESOURCE_LANGUAGE_OPEN
#       1: RESOURCE_LANGUAGE_CLOSED
#
#   word_count: pending words to translate
#
class ResourceLanguage < ApplicationRecord
  include KeywordProjectLanguage
  keyword_language_associations

  belongs_to :text_resource, touch: true
  belongs_to :language
  has_many :money_accounts, foreign_key: :owner_id, class_name: 'ResourceLanguageAccount'

  has_many :resource_chats, dependent: :destroy
  has_one :selected_chat, -> { where(status: RESOURCE_CHAT_ACCEPTED) }, class_name: 'ResourceChat'

  has_many :resource_stats, dependent: :destroy
  has_many :sent_notifications, as: :owner, dependent: :destroy
  has_many :feedbacks, as: :owner, dependent: :destroy

  has_one :managed_work, as: :owner, dependent: :destroy

  def project
    text_resource
  end

  def project_name
    text_resource.name
  end

  def translator
    return nil unless selected_chat
    selected_chat.translator
  end

  def update_version_num
    self.version_num = version_num + 1
    save!
  end

  def find_or_create_account(currency_id = DEFAULT_CURRENCY_ID)
    # look for the translator account in that currency
    account = money_accounts.where(['currency_id = ?', currency_id]).first
    # if this translator doesn't yet have an account in this currency, lets create it now
    unless account
      account = ResourceLanguageAccount.new(currency_id: currency_id)
      account.resource_language = self
      account.save!
    end
    account
  end
  alias money_account find_or_create_account

  def get_output_name
    !output_name.blank? ? output_name : "#{language.name}_*"
  end

  def review_amount
    return 0 unless selected_chat

    if selected_chat.translator.try(:userstatus) != USER_STATUS_PRIVATE_TRANSLATOR
      0.5 * translation_amount
    else
      WebMessage.price_per_word_for(text_resource.client) * 0.5
    end
  end

  def review_enabled?
    managed_work && (managed_work.active == MANAGED_WORK_ACTIVE)
  end

  def set_reviewer(reviewer)
    unless managed_work
      self.managed_work = ManagedWork.new(active: MANAGED_WORK_PENDING_PAYMENT)
      save!
    end
    managed_work.update_attribute :translator_id, reviewer.id
  end

  # Stings that are NOT completed nor being translating
  def count_untraslated_words(plain_text = false)
    # TODO: Strings should be bounded to resource language
    name = "untranslated to #{language.name}"
    strings = text_resource.untranslated_strings(language)
    text_resource.count_words(strings, text_resource.language, self, plain_text, name)
  end

  # this means no payment yet
  def unfunded_words_pending_review_count(plain_text = false)
    # TODO: Strings should be bounded to resource language
    name = "unreviewed to #{language.name}"
    strings = text_resource.unreviewed_strings(language)
    ret = text_resource.count_words(strings, text_resource.language, self, plain_text, name)
    ret
  end

  # strings ready to review
  def funded_words_pending_review_count(plain_text = false)
    # TODO: Strings should be bounded to resource language
    name = "unreviewed to #{language.name}"
    strings = text_resource.pending_review_strings(language)
    ret = text_resource.count_words(strings, text_resource.language, self, plain_text, name)
    ret
  end

  def ready_to_begin?(money_account, plain_text = false)
    return false unless money_account
    return false unless selected_chat

    wc = count_untraslated_words(plain_text)
    wc_review = unfunded_words_pending_review_count(plain_text)
    return false unless wc > 0 || wc_review > 0

    return true if selected_chat.translator.private_translator?

    cost = wc * selected_chat.translation_amount

    cost += wc * review_amount if review_enabled?

    (money_account.balance + 0.01) >= cost
  end

  def review_cost
    return 0 unless review_enabled?
    review_wc = unfunded_words_pending_review_count(false) + count_untraslated_words(false)
    review_wc * review_amount
  end

  def keywords_escrow_amount
    pending_keyword_projects.inject(0) { |a, b| a + b.keyword_package.price }
  end

  def strings_waiting_review
    text_resource.string_translations.where(['
                                              (resource_strings.master_string_id IS NULL) AND
			                                        (string_translations.review_status in (?)) AND
                                              (string_translations.language_id=?)
                                             ',
                                             [REVIEW_PENDING_ALREADY_FUNDED, REVIEW_AFTER_TRANSLATION], language.id])
  end

  def cost_per_word
    return 0 unless selected_chat
    @cost_per_word ||= cost_per_word = if selected_chat.translator.private_translator?
                                         0
                                       else
                                         selected_chat.translation_amount
                                       end
  end

  def cost
    total_required_money
  end

  # Calculates the required funding:
  def total_required_money
    return 0 unless selected_chat

    cost_without_review = count_untraslated_words(false) * cost_per_word
    total_cost = cost_without_review
    total_cost += review_cost if review_enabled?
    planned_expenses = selected_chat.word_count * cost_per_word

    if review_enabled?
      planned_expenses += strings_waiting_review.inject(0) { |a, b| a + b.resource_string.valid_word_count } * review_amount
    end
    current_funds = money_accounts.any? ? money_accounts.first.balance : 0

    extra_funds = current_funds - planned_expenses
    (total_cost - extra_funds).round_money
  end

  def resource_language_escrow_amount
    return 0 unless selected_chat
    cost_per_word = if selected_chat.translator.private_translator?
                      0
                    else
                      selected_chat.translation_amount
                    end

    cost_without_review = count_untraslated_words(false) * cost_per_word

    total_cost = cost_without_review
    total_cost += review_cost if review_enabled?

    planned_expenses = selected_chat.word_count * cost_per_word
    if review_enabled?
      planned_expenses += strings_waiting_review.inject(0) { |a, b| a + b.resource_string.valid_word_count } * review_amount
    end
    current_funds = money_accounts.any? ? money_accounts.first.balance : 0
    extra_funds = current_funds - planned_expenses

    (total_cost - extra_funds).round_money
  end

  def pay_translation_and_review
    amount = total_required_money
    from = text_resource.client.money_account
    to = find_or_create_account(DEFAULT_CURRENCY_ID)
    untranslated_strings = text_resource.untranslated_strings(language)

    if amount > 0
      money_transaction = MoneyTransactionProcessor.transfer_money(from, to, amount, DEFAULT_CURRENCY_ID, TRANSFER_DEPOSIT_TO_RESOURCE_TRANSLATION)
      raise 'Money transaction failed!' unless money_transaction
      money_transaction.owner = self
      money_transaction.save!
    end

    selected_chat.send_strings_to_translation(text_resource, untranslated_strings, amount, review_enabled?)
  end

  def pay
    pay_translation_and_review
  end

  def refund_review
    return unless managed_work.active?

    words_funded_for_review = funded_words_pending_review_count(false)
    review_per_word_cost = review_amount
    amount = words_funded_for_review * review_per_word_cost

    from = money_account
    to = text_resource.client.money_account

    logger.info "Processing review refund for ResourceLanguage##{id} $#{amount}"

    if amount > 0
      ResourceLanguage.transaction do
        money_transaction = MoneyTransactionProcessor.transfer_money(from, to, amount, DEFAULT_CURRENCY_ID, TRANSFER_REFUND_FOR_RESOURCE_TRANSLATION)
        raise 'Money transaction failed!' unless money_transaction
        money_transaction.owner = self
        money_transaction.save!

        # update string status
        res_strings = text_resource.pending_review_strings(language)
        if res_strings.any?
          string_translations = StringTranslation.where(resource_string_id: res_strings.pluck(:id), language_id: language.id)
          string_translations.update_all(review_status: REVIEW_NOT_NEEDED)
          logger.info " #{string_translations.count} strings set to review not needed, ids: #{string_translations.pluck(:id)}"
        end
      end
    end

    true
  end

  # This method is not used in the application, can be used to easily add
  # translator to a resource_language
  def assign_translator(t)
    c = selected_chat || resource_chats.create(status: 2, translation_status: 2)
    c.translator_id = t
    c.save
  end

  def unassign_translator
    chat = selected_chat
    translator = chat.translator
    chat.status = RESOURCE_CHAT_DECLINED
    chat.save!

    if text_resource.client.can_receive_emails?
      ReminderMailer.notify_translator_removed(text_resource, translator, language).deliver_now
    end

    true
  end

  def update_word_count
    return unless selected_chat
    string_translations_to_release = text_resource.string_translations.includes(:resource_string).where(['(string_translations.language_id=?) AND (string_translations.status=?)', selected_chat.resource_language.language_id, STRING_TRANSLATION_BEING_TRANSLATED])
    resource_strings = string_translations_to_release.collect(&:resource_string)
    word_count = text_resource.count_words(resource_strings, text_resource.language, selected_chat.resource_language, false, nil)

    selected_chat.update_attribute :word_count, word_count
  end

  def string_translations
    text_resource.string_translations_for_language(language)
  end

end
