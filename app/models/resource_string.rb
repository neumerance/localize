class ResourceString < ApplicationRecord

  include LengthCounter

  validates_presence_of :token, :txt
  validate :max_width_value

  belongs_to :text_resource, touch: true
  has_many :string_translations, dependent: :destroy
  belongs_to :master_string, foreign_key: :master_string_id, class_name: 'ResourceString'
  has_many :duplicates, foreign_key: :master_string_id, class_name: 'ResourceString'
  has_many :issues, through: :string_translations, dependent: :destroy

  after_save :update_ratios

  before_save :reset_formatted_original

  # deprecated
  SAFE_WORDS = %w(about add adress all app attach block blog buy cancel choose clients comments connected contacts default delete done done download download edit edit enter facebook feedback find forums free home install keyword linkedin location login logout logo members name news no note off ok on password paste pinch projects recent remove reset resources search searching select send settings shake slide status stop surname tags themes tilt today today tomorrow twitter unblock upload username yes yesterday youtube files).freeze

  UNSAFE_WORDS = { 'whip' => true, 'test' => true, 'end' => true, 'cover' => true, 'hope' => true, 'polish' => true, 'nest' => true, 'move' => true, 'form' => true, 'trouble' => true, 'transport' => true, 'step' => true, 'shop' => true, 'crush' => true, 'man' => true, 'sail' => true, 'surprise' => true, 'suit' => true, 'walk' => true, 'turn' => true, 'talk' => true, 'slip' => true, 'nail' => true, 'cause' => true, 'waste' => true, 'place' => true, 'love' => true, 'kiss' => true, 'increase' => true, 'care' => true, 'park' => true, 'level' => true, 'laugh' => true, 'question' => true, 'rain' => true, 'burn' => true, 'spark' => true, 'smoke' => true, 'jail' => true, 'bat' => true, 'glue' => true, 'list' => true, 'back' => true, 'hammer' => true, 'order' => true, 'box' => true, 'push' => true, 'taste' => true, 'shade' => true, 'head' => true, 'branch' => true, 'stretch' => true, 'name' => true, 'joke' => true, 'balance' => true, 'touch' => true, 'smile' => true, 'kick' => true, 'dress' => true, 'note' => true, 'stitch' => true, 'smell' => true, 'curve' => true, 'jam' => true, 'mark' => true, 'trip' => true, 'pump' => true, 'request' => true, 'rub' => true, 'milk' => true, 'offer' => true, 'plant' => true, 'wave' => true, 'use' => true, 'number' => true, 'part' => true, 'screw' => true, 'wash' => true, 'battle' => true, 'spot' => true, 'snow' => true, 'help' => true, 'change' => true, 'record' => true, 'knot' => true, 'fire' => true, 'measure' => true, 'stop' => true, 'smash' => true, 'brush' => true, 'produce' => true, 'drain' => true, 'guide' => true, 'start' => true, 'judge' => true, 'beam' => true, 'play' => true, 'flower' => true, 'force' => true, 'grip' => true, 'jump' => true, 'bubble' => true, 'time' => true, 'sound' => true, 'copy' => true, 'coach' => true, 'rock' => true, 'need' => true, 'fold' => true, 'lock' => true, 'attack' => true, 'hand' => true, 'crack' => true, 'support' => true, 'stamp' => true, 'sign' => true, 'shock' => true, 'point' => true, 'print' => true, 'drop' => true, 'twist' => true, 'store' => true, 'land' => true, 'heat' => true, 'drum' => true, 'fear' => true, 'camp' => true, 'work' => true, 'whistle' => true, 'water' => true, 'interest' => true, 'roll' => true, 'wish' => true, 'watch' => true, 'train' => true, 'trade' => true, 'hook' => true, 'coil' => true, 'hate' => true, 'brake' => true, 'paint' => true, 'dust' => true, 'rule' => true, 'book' => true, 'look' => true, 'sneeze' => true, 'attempt' => true, 'cough' => true, 'bomb' => true, 'join' => true, 'cry' => true, 'sack' => true, 'frame' => true, 'regret' => true, 'answer' => true, 'face' => true, 'trick' => true, 'paste' => true, 'match' => true, 'comb' => true, 'pull' => true, 'mine' => true }.freeze

  before_destroy :cleanup_and_refund

  def user_can_delete_original(user)
    (
      [user, user.master_account].include?(text_resource.client) ||
       user.has_supporter_privileges?
    ) &&
      user.can_modify?(text_resource)
  end

  def user_can_edit_original(user)
    if [user, user.master_account].include?(text_resource.client) && user.can_modify?(text_resource)
      true
    else
      false
    end
  end

  def unclear?
    if unclear.nil?
      self.unclear = (comment.nil? || comment.empty?) && (has_placeholders || (has_only_one_word && unsafe_word(txt)))
      save
    end
    unclear
  end

  def has_only_one_word
    txt && (txt.split(' ').size == 1)
  end

  def has_placeholders
    !placeholders.empty?
  end

  def placeholders
    txt.split(' ').find_all { |word| %w($ %).include?(word.at(0)) }
  end

  # deprecated
  def safe_word(word)
    SAFE_WORDS.include?(word.downcase)
  end

  def unsafe_word(word)
    UNSAFE_WORDS[word.to_s] == true
  end

  def user_can_edit_translation(user, language)
    string_translation = string_translations.find_by(language_id: language.id)

    if ([user, user.master_account].include?(text_resource.client) || user.has_supporter_privileges?) && user.can_modify?(text_resource) && (!string_translation || (string_translation.status != STRING_TRANSLATION_BEING_TRANSLATED))
      return true
    end

    if (user[:type] == 'Translator') && string_translation && ((string_translation.status == STRING_TRANSLATION_BEING_TRANSLATED) || (string_translation.status == STRING_TRANSLATION_COMPLETE))
      # check that the client has enough credit for this translation
      resource_language = text_resource.resource_languages.find_by(language_id: language.id)
      return false unless resource_language

      # make sure it's the translator and not the editor
      edit_language = text_resource.resource_chats.where('(translator_id=?) AND (resource_chats.status=?) AND (resource_language_id=?)', user.id, RESOURCE_CHAT_ACCEPTED, resource_language.id).first
      return false unless edit_language

      # if we're not going to pay, no need to check the balance
      return true if string_translation.pay_translator != 1

      resource_chat = resource_language.resource_chats.find_by(translator_id: user.id)
      return false unless resource_chat

      language_account = resource_language.find_or_create_account(DEFAULT_CURRENCY_ID)
      has_enough_balance = (language_account.balance + 0.01) >= (self.word_count * resource_chat.translation_amount)
      if has_enough_balance
        return true
      else
        # Sometimes the string_translation is with status = 3, being translated
        #   that means that is marked as funded, but there is not enough funds,
        #   so translators dont see the button, and client dont see the missing funds message.
        #   this force client to mark as translated
        if string_translation.status == STRING_TRANSLATION_BEING_TRANSLATED
          string_translation.update_attribute :status, STRING_TRANSLATION_MISSING
          Rails.logger.info(" *** The escrow account for this resource language don't have enough funds, returning string to missing funds status *** ")
        end
        return false
      end
    else
      return false
    end
  end

  def update_ratios
    ActiveRecord::Base.record_timestamps = false
    string_translations.each(&:save)
    ActiveRecord::Base.record_timestamps = true
  end

  def get_translation(language)
    language = Language[language] if [String, Symbol].include?(language.class)

    r = string_translations.select { |st| st.language_id == language.id }
    r.try :first
  end
  alias for_language get_translation

  def cleanup_and_refund
    refund
    cleanup
  end

  def max_width_in_chars
    return nil unless max_width

    (max_width * txt.mb_chars.size) / 100
  end

  def word_count
    self[:word_count] || update_word_count
  end

  def update_word_count
    self.word_count = text_resource.count_words([self], text_resource.language, nil)
  end

  def valid_word_count
    txt.sanitized_split.length
  end

  private

  def max_width_value
    unless max_width.nil?
      errors.add(:max_width, 'cannot be smaller than 50 percent') if max_width < 50
    end
  end

  def cleanup
    text_resource.resource_strings.where('master_string_id = ?', id).find_each do |rs|
      # Now it don't have a master string any longer
      rs.update_attributes(master_string_id: nil)

      # Update the translations from this string
      rs.string_translations.each do |st|
        this_st = string_translations.find_by(language_id: st.language_id)
        next unless this_st
        st.txt = this_st.txt
        st.status = this_st.status
        st.review_status = this_st.review_status
        st.save!
      end
    end

    # Removes string from the cache (if was marked to translate)
    string_translations.where(status: STRING_TRANSLATION_BEING_TRANSLATED).find_each do |string_translation|
      selected_chat = string_translation.try(:resource_language).try(:selected_chat)
      if selected_chat
        selected_chat.word_count -= valid_word_count
        selected_chat.save!
      end
    end
  end

  def refund
    # refund translation cost
    string_translations.
      where(status: STRING_TRANSLATION_BEING_TRANSLATED).
      find_each(&:refund)

    # refund review cost
    string_translations.
      where(review_status: [REVIEW_PENDING_ALREADY_FUNDED, REVIEW_AFTER_TRANSLATION]).
      find_each(&:refund_review)
  end

  def reset_formatted_original
    self.formatted_original = nil if txt_changed?
  end
end
