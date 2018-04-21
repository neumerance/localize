require 'base64'
#   translation_status:
#     TRANSLATION_PENDING_CLIENT_REVIEW = 0
#     TRANSLATION_NOT_NEEDED = 1
#     TRANSLATION_NEEDED = 2
#     TRANSLATION_IN_PROGRESS = 3
#     TRANSLATION_COMPLETE = 4
#     TRANSLATION_REFUSED = 5
#     TRANSLATION_NOT_DELIVERED = 6 # DEPRECATED LAST USAGE: 2009
#     TRANSLATION_NEEDS_EDIT = 7

class WebMessage < ApplicationRecord
  belongs_to :client
  belongs_to :user
  belongs_to :owner, polymorphic: true
  belongs_to :money_account
  belongs_to :translator, touch: true
  belongs_to :client_language, class_name: 'Language', foreign_key: :client_language_id
  belongs_to :visitor_language, class_name: 'Language', foreign_key: :visitor_language_id
  has_one :money_transaction, as: :owner
  has_many :web_attachments
  has_many :messages, as: :owner, dependent: :destroy

  has_one :managed_work, as: :owner, dependent: :destroy
  has_many :issues, as: :owner, dependent: :destroy

  validates_presence_of :comment, message: _('Please provide description for the text')
  validates_presence_of :client_language, message: _('You must select the language to translate from')
  validates :client_body, length: { maximum: COMMON_NOTE }
  validates :visitor_body, length: { maximum: COMMON_NOTE }

  scope :funded, lambda {
    where(translation_status: [
            TRANSLATION_PENDING_CLIENT_REVIEW,
            TRANSLATION_IN_PROGRESS,
            TRANSLATION_COMPLETE,
            TRANSLATION_NEEDS_EDIT
          ])
  }

  scope :missing_payment, lambda {
    where(translation_status: [
            TRANSLATION_NEEDED,
            TRANSLATION_NOT_NEEDED,
            TRANSLATION_REFUSED
          ])
  }

  TOKEN_REGEX = /(\{{2})((\s*.[^{}]*.\s*))(\}{2})/

  TRANSLATION_STATUS_TEXT = { TRANSLATION_PENDING_CLIENT_REVIEW => N_('Pending review'),
                              TRANSLATION_NOT_NEEDED => N_('Translation not needed'),
                              TRANSLATION_NEEDED => N_('Waiting to be translated'),
                              TRANSLATION_IN_PROGRESS => N_('Translation in progress'),
                              TRANSLATION_COMPLETE => N_('Translation complete'),
                              TRANSLATION_REFUSED => N_('Translation not needed'),
                              TRANSLATION_NOT_DELIVERED => N_('Translation not delivered') }.freeze

  TRANSLATION_AND_REVIEW_STATUS = { TRANSLATION_PENDING_CLIENT_REVIEW => { nil => N_('Pending review') },
                                    TRANSLATION_NOT_NEEDED => { nil => N_('Translation not needed') },
                                    TRANSLATION_NEEDED => { nil => N_('Waiting for translation'),
                                                            MANAGED_WORK_CREATED => N_('Waiting for translation and review') },
                                    TRANSLATION_IN_PROGRESS => { nil => N_('Translation in progress') },
                                    TRANSLATION_COMPLETE => { nil => N_('Translation complete'),
                                                              MANAGED_WORK_CREATED => N_('Waiting for review'),
                                                              MANAGED_WORK_WAITING_FOR_REVIEWER => N_('Waiting for reviewer'),
                                                              MANAGED_WORK_REVIEWING => N_('Being reviewed'),
                                                              MANAGED_WORK_COMPLETE => N_('Translated and reviewed') },
                                    TRANSLATION_REFUSED => { nil => N_('Translation not needed') },
                                    TRANSLATION_NOT_DELIVERED => { nil => N_('Translation not delivered') } }.freeze

  TRANSLATION_UPDATE_TEXT = { TRANSLATION_COMPLETED_OK => 'Translation completed OK',
                              TRANSLATION_NOT_YOUR => 'Not your message',
                              BLANK_TRANSLATION_ENTERED => 'Blank translation entered',
                              TRANSLATION_ALREADY_COMPLETED => 'Translation already completed',
                              TRANSLATION_FAILED_TO_DECODE => 'Transtation failed to decode',
                              TRANSLATION_MISSING_TOKENS => 'Translation missing tokens',
                              TRANSLATION_REQUIRES_REVIEW => 'Translation requires review',
                              TRANSLATION_COMPLETION_FAILED => 'Translation completion failed' }.freeze

  REVIEW_STATUS_TEXT = { REVIEW_NOT_NEEDED => N_('Review not needed'),
                         REVIEW_AFTER_TRANSLATION => N_('Will review after translation'),
                         REVIEW_PENDING_ALREADY_FUNDED => N_('Review needed'),
                         REVIEW_COMPLETED => N_('Review completed') }.freeze

  attr_reader :text_md5, :title_md5, :comment_md5

  validate :validate_comment_on_create, on: :create

  validates_each :word_count, on: :save do |model, attr, value|
    model.errors.add(attr, _('cannot be zero')) if value.nil? || (value == 0)
  end

  validates_each :client_language_id, :visitor_language_id, on: :save do |model, attr, value|
    model.errors.add(attr, _('must be selected')) if value.nil? || (value == 0)
  end

  def validate_comment_on_create
    if comment.blank?
      errors.add(:comment, 'Please provide description for the text')
    end
  end

  def get_client
    if owner_type == 'Website'
      owner.client
    else
      owner
    end
  end

  def reviewer_payment
    translator_payment * 0.5
  end

  def price_per_word
    if owner.class == Website
      contract = owner.website_translation_contracts.joins(:website_translation_offer).where('(website_translation_offers.from_language_id=?) AND (website_translation_offers.to_language_id=?) AND (website_translation_contracts.status=?)', original_language_id, destination_language_id, TRANSLATION_CONTRACT_ACCEPTED).first
      return contract.amount if contract
    end

    WebMessage.price_per_word_for(owner)
  end

  def review_price_per_word
    WebMessage.review_price_per_word_for(owner)
  end

  def translation_price
    (word_count * price_per_word).ceil_money
  end
  alias translator_payment translation_price

  def review_price
    (word_count * review_price_per_word).ceil_money
  end

  def tax_cost
    ((Float(price.to_f) * Float(get_client.country.tax_rate)) / 100).ceil_money
  end

  # Full price WITH taxes
  def client_cost
    if get_client && get_client.has_to_pay_taxes?
      price + tax_cost
    else
      price
    end
  end
  alias client_price client_cost

  # Full price WITHOUT taxes
  def price
    if managed_work && managed_work.enabled?
      translation_price + review_price
    else
      translation_price
    end
  end

  def review_complete
    ManagedWork.transaction do
      managed_work.update_attribute :translation_status, MANAGED_WORK_COMPLETE

      amount = reviewer_payment
      from = money_account
      to = managed_work.translator.get_money_account(DEFAULT_CURRENCY_ID)
      MoneyTransactionProcessor.transfer_money(from, to, amount, 0, TRANSFER_PAYMENT_FOR_INSTANT_TRANSLATION, FEE_RATE, nil, :hold_sum, self)

      if (owner.class == Client) && owner.can_receive_emails?
        InstantMessageMailer.instant_translation_reviewed(self).deliver_now
      end
    end
  end

  def update_text(decoded_body, decoded_title, need_title_translation)
    self.client_body = decoded_body

    if need_title_translation
      owner.update_attributes(client_subject: decoded_title)
    end
    save!
  end

  def update_translation(decoded_body, decoded_title, need_title_translation)
    self.visitor_body = decoded_body
    self.translate_time = Time.now

    if need_title_translation
      owner.update_attributes(client_subject: decoded_title)
    end
    save
  end

  def translation_in_progress?
    translation_status == TRANSLATION_IN_PROGRESS
  end

  def translation_complete?
    translation_status == TRANSLATION_COMPLETE
  end

  def complete_translation
    WebMessage.transaction do
      self.translation_status = TRANSLATION_COMPLETE
      save!

      amount = translator_payment
      from = money_account
      to = translator.get_money_account(DEFAULT_CURRENCY_ID)
      MoneyTransactionProcessor.transfer_money(from, to, amount, 0, TRANSFER_PAYMENT_FOR_INSTANT_TRANSLATION, FEE_RATE, nil, :hold_sum, self)

      if managed_work.try(:active?) && managed_work.try(:translator) && (money_account.balance + 0.01 >= reviewer_payment)
        money_account.balance -= reviewer_payment
        money_account.hold_sum += reviewer_payment
        money_account.save!

        managed_work.update_attribute :translation_status, MANAGED_WORK_REVIEWING
        if managed_work.translator.can_receive_emails?
          ReminderMailer.web_message_to_review(managed_work.translator, self).deliver_now
        end
      end
    end
    TRANSLATION_COMPLETED_OK
  rescue => e
    logger.error e.inspect
    logger.error e.backtrace.join("\n")
    TRANSLATION_COMPLETION_FAILED
  end

  def complex?
    if complex_flag_users.nil?
      false
    else
      logger.debug YAML.load(complex_flag_users).inspect
      YAML.load(complex_flag_users).size >= WEB_MESSAGE_COMPLEX_N_FLAGS
    end
  end

  def client_body_for_word_count
    client_body.gsub(/\{\{.*?\}\}/, 'token')
  end

  def release_from_hold
    unless translation_in_progress?
      Rails.logger.info 'Translation not in progress'
      return TRANSLATION_NOT_IN_PROGRESS
    end

    begin
      WebMessage.transaction do
        amount = translation_price

        if money_account.hold_sum < amount
          raise "Not enough hold_sum amount for webmesage ##{id} on account ##{money_account.id} \nTranslation Price: $#{amount}\nHold Sum on Money Account: $#{money_account.hold_sum}"
        end

        money_account.balance += amount
        money_account.hold_sum -= amount
        money_account.save!

        self.translation_status = TRANSLATION_NEEDED
        self.translator_id = nil
        self.translate_time = nil
        save!

        return MESSAGE_RELEASED_FROM_HOLD
      end
    rescue => e
      Rails.logger.info " ----- !!! NOT ABLE TO release IT ##{id} from hold #{e.message}"
      InternalMailer.exception_report(e).deliver_now

      return HOLD_FOR_TRANSLATION_FAILED
    end
  end
  alias unstuck release_from_hold

  def release_from_translation(translator)
    @err = nil
    if self.translation_status != TRANSLATION_IN_PROGRESS
      return ApiError.new(404, 'Nothing to release').error
    end
    if self.translator != translator
      return ApiError.new(403, 'Not your to release').error
    end

    begin
      release_result = release_from_hold
      if release_result == MESSAGE_RELEASED_FROM_HOLD
        return { code: 200, message: 'OK' }
      else
        raise 'Not able to release IT'
      end
    rescue => e
      logger.info " ----- !!! NOT ABLE TO release from hold #{e.message}"
      return ApiError.new(503, 'An error occured, please try again later').error
    end
  end

  def body_for_user(is_client)
    if is_client
      !client_body.blank? ? client_body : visitor_body
    else
      if !client_body.blank? && !visitor_body.blank?
        decoded, problems = update_token_data(visitor_body, client_body)
        if problems.empty?
          return decoded
        else
          return visitor_body
        end
      else
        !visitor_body.blank? ? visitor_body : client_body
      end
    end
  end

  def associate_with_dialog(web_dialog, txt = nil)
    self.owner = web_dialog
    self.visitor_language_id = web_dialog.visitor_language_id
    self.client_language_id = web_dialog.client_department.language_id
    self.money_account = web_dialog.client_department.web_support.client.get_money_account(DEFAULT_CURRENCY_ID)
    self.comment = 'This message is part of a support ticket' if comment.blank?

    if translation_status == 0
      self.translation_status = if web_dialog.visitor_language_id != web_dialog.client_department.language_id
                                  web_dialog.client_department.translation_status_on_create
                                else
                                  TRANSLATION_NOT_NEEDED
                                end
    end
    unless txt.blank?
      # the word count will include this message's word count and optionally, the title's word count

      asian_language = Language.asian_language_ids.include?(original_language_id)

      txt_wc = asian_language ? (WebMessage.tokenize(txt).length / UTF8_ASIAN_WORDS).ceil : WebMessage.tokenize(txt).split_text.length
      if need_title_translation
        title_txt = title_to_translate(false)
        txt_wc += asian_language ? (title_txt.length / UTF8_ASIAN_WORDS).ceil : title_txt.split_text.length
      end
      self.word_count = txt_wc
    end
    save!
  end

  def original_language_id
    if user_id.blank?
      visitor_language_id
    else
      client_language_id
    end
  end

  def destination_language_id
    if user_id.blank?
      client_language_id
    else
      visitor_language_id
    end
  end

  def original_language
    if user_id.blank?
      visitor_language
    else
      client_language
    end
  end

  def destination_language
    if user_id.blank?
      client_language
    else
      visitor_language
    end
  end

  def original_text
    user_id.blank? ? visitor_body : client_body
  end

  def text_to_translate(base64_encode = true)
    res = user_id.blank? ? visitor_body : WebMessage.tokenize(client_body)
    res = Base64.encode64(res) if base64_encode
    @text_md5 = Digest::MD5.hexdigest(res)
    res
  end

  def need_title_translation
    (owner_type == 'WebDialog') && owner.is_first_message(self)
  end

  def title_to_translate(enc = true)
    res = if enc
            Base64.encode64(owner.text_to_translate)
          else
            owner.text_to_translate
          end
    @title_md5 = Digest::MD5.hexdigest(res)
    res
  end

  def translation
    user_id.blank? ? client_body : visitor_body
  end

  def decoded_translation(user, _force_decode = false)
    if user_id.blank?
      client_body
    else
      if user && !user_id.blank? && (user[:type] == 'Client') && [TRANSLATION_COMPLETE, TRANSLATION_NOT_DELIVERED].include?(translation_status) && (old_format != 1)
        decoded, problems = update_token_data(visitor_body, client_body)
        if problems.empty?
          return decoded
        else
          return visitor_body
        end
      else
        visitor_body
      end
    end
  end

  def encoded_comment
    res = Base64.encode64(comment)
    @comment_md5 = Digest::MD5.hexdigest(res)
    res
  end

  # returns number of seconds to translate
  def timeout
    word_time = word_count * MAX_TIME_TO_TRANSLATE_WORD
    word_time < 10.minutes.to_i ? 10.minutes.to_i : word_time
  end

  def belongs_to_user?(user)
    translator == user
  end

  def has_enough_money_for_translation?
    money_account && ((money_account.balance + 0.01) >= client_cost)
  end

  def tokenize
    WebMessage.tokenize(client_body)
  end

  def has_tokens?
    client_body != tokenize
  end

  def decoded_visitor_body(user, _force_decode = false)
    if user && !user_id.blank? && (user[:type] == 'Client') && [TRANSLATION_COMPLETE, TRANSLATION_NOT_DELIVERED].include?(translation_status) && (old_format != 1)
      decoded, problems = update_token_data(visitor_body, client_body)
      if problems.empty?
        return decoded
      else
        return visitor_body
      end
    else
      visitor_body
    end
  end

  def update_token_data(translation, orig)
    problems = []

    token_data = {}
    i = 0
    orig.gsub(TOKEN_REGEX) { |p| i += 1; token_data[i] = p }

    tokens_in_translation = {}
    translation.gsub(TOKEN_REGEX) { |p| i += 1; tokens_in_translation[i] = p }

    # make sure all tokens exist in the translation
    if token_data.length != tokens_in_translation.length
      problems << "Incorrect number of tokens. Should be #{token_data.length} tokens, found #{tokens_in_translation.length}"
    end
    token_data.each do |k, v|
      token = "{{#{WebMessage.token_key(v)}:#{k}}}"
      unless tokens_in_translation.value?(token)
        problems << "Missing token in translation: #{token}"
      end
    end

    return nil, problems unless problems.empty?

    # replace the tokens from the translation with the values from the original data
    res = translation
    token_data.each do |k, v|
      res = res.gsub("{{#{WebMessage.token_key(v)}:#{k}}}", WebMessage.token_txt(v))
    end

    [res, []]
  end

  def get_name
    if !name.blank?
      name
    elsif !client_body.blank?
      client_body
    else
      visitor_body
    end
  end

  def translation_and_review_status
    return 'Flagged as complex' if complex?

    if translation_status == TRANSLATION_NEEDED && !has_enough_money_for_translation?
      return 'Not enough funds'
    end

    st = TRANSLATION_AND_REVIEW_STATUS[translation_status]
    review_status = managed_work ? managed_work.translation_status : nil
    if st.key?(review_status)
      return st[review_status]
    else
      return st[nil]
    end
  end

  def user_can_edit?(user)
    return false if user != translator

    can_edit_statuses = [TRANSLATION_IN_PROGRESS,
                         TRANSLATION_NEEDS_EDIT,
                         TRANSLATION_COMPLETE]

    can_edit_statuses.include? translation_status
  end

  def can_modify_review_status
    can_modify_review_status = [TRANSLATION_PENDING_CLIENT_REVIEW,
                                TRANSLATION_NEEDED,
                                TRANSLATION_IN_PROGRESS,
                                TRANSLATION_COMPLETE,
                                TRANSLATION_NEEDS_EDIT,
                                TRANSLATION_NOT_DELIVERED].include?(translation_status)
    if can_modify_review_status && managed_work
      can_modify_review_status = [MANAGED_WORK_CREATED].include? managed_work.translation_status
    end

    can_modify_review_status
  end

  def take_for_translation(translator)
    has_current = WebMessage.has_current_it_job(translator)
    return ApiError.new(412, 'You have unfinished instant translation, please complete it first before taking this one.').error if has_current

    unless self.owner.is_a? WebDialog
      unless (translator.from_languages.include?(self.client_language) &&
          translator.to_languages.include?(self.visitor_language)) ||
             (self.client && self.client.all_private_translators.include?(translator))
        return ApiError.new(403, "You can't translate from/to this languages").error
      end
    end

    amount = self.translator_payment

    if (self.translation_status != TRANSLATION_NEEDED) || !self.translator_id.nil?
      return ApiError.new(409, 'Message already assigned').error
    elsif self.money_account.balance < amount
      return ApiError.new(412, "Client doesn't have enough funds to complete this job").error
    else
      # if this fails, nothing is changed - the user can try again
      begin
        WebMessage.transaction do
          self.money_account.move_to_hold_sum(amount)

          self.translation_status = TRANSLATION_IN_PROGRESS
          self.translator = translator
          self.translate_time = Time.now # until translated, this holds the hold time
          self.save!
          @remaining_time = (self.timeout - (Time.now - self.translate_time)).to_i - 5
        end
      rescue => e
        logger.info e.message
        logger.info e.backtrace
        return ApiError.new(503, 'Unknown error, please try again').error
      end
    end

    { code: 200, message: 'OK', remaining_time: @remaining_time }

  end

  # remaining time to translate in seconds
  def remaining_time

    (timeout - (Time.now - translate_time)).to_i
  rescue
    0

  end

  def has_time?
    remaining_time > 0
  end

  def api_save_it(body, current_user)
    decoded_body = body

    @err = if (translation_status != TRANSLATION_IN_PROGRESS) && (translator != current_user)
             ApiError.new(409, 'Translation already completed')
           elsif body.blank?
             ApiError.new(411, 'Translation cannot be empty')
           elsif decoded_body.blank?
             ApiError.new(400, 'Can\'t decode translation')
           end

    return @err if @err

    unless self.user_id.blank?
      untokenized_text, problems = self.update_token_data(decoded_body, self.client_body)
      return ApiError.new(409, "Missing token: #{problems.join(', ')}").error if problems.any?
    end

    return ApiError.new(406, 'The translated body is identical to the original body').error if decoded_body.delete(' ') == original_text.delete(' ') && original_text.count_words > 1

    if self.user_id.blank?
      self.client_body = decoded_body
    else
      self.visitor_body = decoded_body
      self.translate_time = Time.now
    end
    begin
      self.save!
    rescue => e
      Rails.logger.error("Saving IT failed for #{self.id} with #{e.inspect}")
      return ApiError.new(503, 'Saving of instant translation failed').error
    end

    @err_code = if self.translation_in_progress?
                  self.complete_translation
                else
                  TRANSLATION_COMPLETED_OK
                end

    return ApiError.new(503, 'Failed to complete translation').error unless @err_code == TRANSLATION_COMPLETED_OK

    if self[:owner_type] == 'WebDialog' && self.user_id.blank?
      if self.owner.client_department.web_support.client.can_receive_emails?
        InstantMessageMailer.notify_client(self.owner, self, false).deliver_now
      end
    elsif self[:owner_type] == 'WebDialog'
      set_locale_for_lang(self.owner.visitor_language)
      if self.owner.can_receive_emails?
        InstantMessageMailer.notify_visitor(self.owner, self, self.owner.visitor_language).deliver_now
      end
    elsif (self[:owner_type] == 'User') || (self[:owner_type] == 'NormalUser') || (self[:owner_type] == 'Client')
      if self.owner.can_receive_emails?
        InstantMessageMailer.instant_translation_complete(self).deliver_now
      end
    elsif self[:owner_type] == 'Website'
      unless self.owner.send_translated_message(self)
        self.update_attributes(translation_status: TRANSLATION_NOT_DELIVERED)
      end
    end

    @err
  end

  delegate :id, to: :get_client, prefix: true

  class << self

    def has_current_it_job(translator)
      where(translator_id: translator.id, translation_status: 3).any?
    end

    def token_txt(token)
      idx = (/\|\|/ =~ token)
      if !idx.nil? && (idx > 0)
        return token[2...idx]
      else
        return token[2..-3]
      end
    end

    def token_key(token)
      idx = (/\|\|/ =~ token)
      if !idx.nil? && (idx > 0)
        return token[(idx + 2)..-3]
      else
        return 'T'
      end
    end

    def tokenize(s)
      i = 0
      s.gsub(TOKEN_REGEX) { |p| i += 1; "{{#{token_key(p)}:#{i}}}" }
    end

    def has_tokens?(s)
      s != tokenize(s)
    end

    def price_per_word_for(user)
      if user && user.is_a?(User) && user.top
        INSTANT_TRANSLATION_COST_PER_WORD * TOP_CLIENT_DISCOUNT
      else
        INSTANT_TRANSLATION_COST_PER_WORD
      end
    end

    def review_price_per_word_for(user)
      if user && user.is_a?(User) && user.top
        INSTANT_TRANSLATION_COST_PER_WORD * 0.5 * TOP_CLIENT_DISCOUNT
      else
        INSTANT_TRANSLATION_COST_PER_WORD * 0.5
      end
    end

    def price_with_review_per_word_for(user)
      price_per_word_for(user) + review_price_per_word_for(user)
    end

    # this function should be run periodically to release stale messages, which should no longer be held by translators
    def release_old_holds(_curtime = Time.now)
      res = []
      # get all the messages that are currently being translated
      messages_in_progress = where(translation_status: TRANSLATION_IN_PROGRESS)
      messages_in_progress.each do |message|
        next if message.has_time?

        release_result = message.release_from_hold
        res << message if release_result == MESSAGE_RELEASED_FROM_HOLD
      end
      res
    end

    def missing_funding_for_user(user, extra_sql = '')
      account_balance = user.money_account ? user.money_account.balance : 0
      res = 0
      total = user.web_messages_pending_translation(extra_sql).map(&:translation_price).sum
      total += user.web_messages_pending_review(extra_sql).map(&:review_price).sum
      # total = user.web_messages_pending_translation(extra_sql).map(&:client_cost).sum
      res += (total - account_balance) if total >= account_balance
      res
    end

    # used from supporter controller
    # get all projcts waiting action for more than one hour.
    def old_untranslated(only_status = false)
      pending_status = only_status || [TRANSLATION_NEEDED, TRANSLATION_PENDING_CLIENT_REVIEW]
      where('(web_messages.translation_status IN (?)) AND (UNIX_TIMESTAMP(create_time) < ?) AND web_messages.owner_type != ?', pending_status, 1.hour.ago.to_i, 'WebDialog').order('id DESC')
      # @ToDo purge those messages from a cronjob
      # messages.delete_if{|m| m.money_account.nil? or m.money_account.balance <= m.price}
    end

    def pending(only_status = false)
      pending_status = only_status || [TRANSLATION_NEEDED, TRANSLATION_PENDING_CLIENT_REVIEW]
      where('(web_messages.translation_status IN (?)) AND web_messages.owner_type != ?', pending_status, 'WebDialog').order(id: :desc, create_time: :desc)
    end

  end
end
