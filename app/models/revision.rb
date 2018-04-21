#
#   kind:
#      0: TA_PROJECT # From TA
#      1: MANUAL_PROJECT # Any file (doc, image...)
#      2: SIS_PROJECT # sisulizer file project
#
#      * TA_PROJECT && SIS_PROJECT pays per word, MANUAL_PROJECTS pay per language

class Revision < ApplicationRecord
  acts_as_ferret(fields: [:name, :description],
                 index_dir: "#{FERRET_INDEX_DIR}/revision",
                 remote: true)

  validates_presence_of :name
  validates_numericality_of :released
  validates_numericality_of :max_bid, :auto_accept_amount
  validates :description, length: { maximum: COMMON_NOTE }

  attr_reader :chat_closed_reason, :chat_closed_link

  belongs_to :project
  belongs_to :currency, foreign_key: :max_bid_currency
  belongs_to :language
  belongs_to :cms_request
  has_one :website, through: :cms_request

  has_one :client, through: :project
  has_many :reminders, as: :owner, dependent: :destroy
  has_many :versions, foreign_key: :owner_id, dependent: :destroy
  has_many :chats, dependent: :destroy
  has_many :all_bids, through: :chats, class_name: 'Bid', source: :bids
  has_many :revision_languages, dependent: :destroy
  has_many :languages, through: :revision_languages
  has_many :revision_categories, dependent: :destroy
  has_many :categories, through: :revision_categories
  has_many :revision_support_files, dependent: :destroy
  has_many :support_files, through: :revision_support_files
  has_many :translators, through: :chats
  has_many :sent_notifications, as: :owner, dependent: :destroy
  has_many :keyword_projects, through: :revision_languages

  has_one :support_ticket, as: :object

  include Trackable
  include ParentWithSiblings

  include KeywordProjectMethods

  before_destroy :cleanup_before_destroy, prepend: true

  def project_languages
    revision_languages
  end

  def languages_to
    revision_languages.map(&:language)
  end

  def translator_for(language)
    selected_bid = revision_languages.find_by(language_id: language.id).selected_bid
    selected_bid.chat.translator if selected_bid
  end

  def reviewer_for(language)
    mw = revision_languages.find_by(language_id: language.id).try(:managed_work)
    mw.translator if mw && mw.active?
  end

  def ta?
    kind == TA_PROJECT
  end

  def practice_project?
    client.email == DEMO_CLIENT_EMAIL
  end

  def from_cms?
    !cms_request.nil?
  end

  def pending_bids
    all_bids.where(status: BID_WAITING_FOR_PAYMENT)
  end

  def pending_managed_works
    # Select only managed works that have a selected bid - we can't pay the ones that don't have a bid accepted
    managed_works = revision_languages.find_all(&:selected_bid).map(&:managed_work)
    managed_works.find_all { |mw| mw && mw.pending_payment? }
  end

  def pending_translators_cost
    pending_bids.inject(0) { |a, b| a + b.translator_payment.ceil_money }
  end

  def pending_reviewers_cost
    pending_managed_works.inject(0) { |a, b| a + b.reviewer_payment.ceil_money }
  end

  def pending_cost
    pending_reviewers_cost + pending_translators_cost
  end

  def pending_translation_and_review_cost
    pending_reviewers_cost + pending_translators_cost
  end

  def user_can_create_chat(user)
    open_language_ids = open_translation_languages.collect(&:language_id)

    if is_test?
      @chat_closed_reason = _('This is a test project.')
      return false
    elsif user.has_supporter_privileges?
      return true
    elsif user.chats.where(revision_id: id).first
      @chat_closed_reason = _('You already have a chat on this project.')
      return false
    elsif project.not_last_revision?(self)
      @chat_closed_reason = _('Newer revisions of this project exist.')
      @chat_closed_link = [_("All project's revisions"), { controller: :projects, action: :show, id: project_id }]
      return false
    elsif open_language_ids.empty?
      @chat_closed_reason = _('No languages to translate to.')
      return false
    elsif user && (user[:type] == 'Translator')
      if (kind == TA_PROJECT) && (user.userstatus != USER_STATUS_QUALIFIED)
        @chat_closed_reason = _('You must be do a practice project before bidding on live projects.')
        @chat_closed_link = [_('Request a practice project'), { controller: :users, action: :request_practice_project }]
        return false
      elsif !user.translator_language_froms.where('(translator_languages.status=?) AND (translator_languages.language_id=?)', TRANSLATOR_LANGUAGE_APPROVED, language_id).first
        @chat_closed_reason = _('You are not qualified to translate from %s.') % language.name
        @chat_closed_link = [_('Check your translation languages'), { controller: :users, action: :translator_languages, id: user.id }]
        return false
      elsif !user.translator_language_tos.where('(translator_languages.status=?) AND (translator_languages.language_id IN (?))', TRANSLATOR_LANGUAGE_APPROVED, open_language_ids).first
        @chat_closed_reason = _('You are not qualified to translate to any of the target languages.')
        @chat_closed_link = [_('Check your translation languages'), { controller: :users, action: :translator_languages, id: user.id }]
        return false
      end
    end

    if !has_open_work
      @chat_closed_reason = _("This project doesn't have any open work. Either all languages are being worked on, or bidding has closed.")
      return false
    else
      return true
    end

  end

  def base_copy(other_revision)
    other_revision.revision_languages.each do |revision_language|
      rl = RevisionLanguage.new(language_id: revision_language.language_id)
      revision_languages << rl
    end

    self.max_bid = other_revision.max_bid
    self.max_bid_currency = other_revision.max_bid_currency
    self.bidding_duration = other_revision.bidding_duration
    self.project_completion_duration = other_revision.project_completion_duration
    save
  end

  def open_to_bids
    if @open_to_bids_cache.nil?
      @open_to_bids_cache = if has_open_work
                              1
                            else
                              0
                            end
    end

    @open_to_bids_cache
  end

  def selected_bids
    revision_languages.map(&:selected_bid).delete(nil)
  end

  def open_bids
    revision_languages.map(&:open_bids).delete(nil)
  end

  def has_open_work
    if released != 1
      return false
    elsif bidding_close_time && (Time.now > bidding_close_time)
      return false
    end
    !open_translation_languages.empty?
  end

  def work_in_progress?
    revision_languages.each do |rl|
      selected_bid = rl.selected_bid
      if selected_bid && !BID_COMPLETE_STATUS.include?(selected_bid.status)
        return true
      end
    end
    false
  end

  def open_translation_languages
    revision_languages.where('NOT EXISTS (SELECT b.id from bids b WHERE (b.revision_language_id=revision_languages.id) AND (b.won = 1))')
  end

  def work_complete
    if revision_languages.count > 0
      open_revision_language = revision_languages.where("NOT EXISTS (
        SELECT b.id FROM bids b WHERE
          (b.revision_language_id=revision_languages.id) AND
          (b.status IN (?)))", BID_COMPLETE_STATUS).first
      open_revision_language.nil? ? 1 : 0
    else
      0
    end
  end

  # give a list of bids for this revision, either filtered by chat_id or for the entire revision
  # [ language, [bid1, bid2, ...], ]
  def bids(chat_id = nil)
    res = []
    for rev_lang in revision_languages
      lang_bids = if chat_id.nil?
                    rev_lang.bids
                  else
                    rev_lang.bids.where(chat_id: chat_id).to_a
                  end
      item = [rev_lang.language, lang_bids]
      res << item if item.flatten.compact.present?
    end
    res
  end

  def chats_with_no_bids
    chats.select('DISTINCT chats.*').where('NOT EXISTS (SELECT * FROM bids WHERE (bids.chat_id=chats.id))')
  end

  def client_can_create_version
    (released == 0) && versions.empty?
  end

  def client_can_update_version
    (released == 0) && !versions.empty?
  end

  def translator_can_create_version(user)
    # find the translator's chat for this revision
    if user[:type] == 'Client'
      true
    elsif user[:type] == 'Translator'
      return true if user.is_reviewer_of?(self)

      chat = user.chats.where(revision_id: id).first
      return false unless chat

      # verify that there is an accepted bid
      bid = chat.bids.where(won: 1)
      return false unless bid

      true
    else
      false
    end
  end

  def has_active_bids
    res = false
    for revision_language in revision_languages
      revision_language_is_complete = false
      if revision_language.selected_bid
        if BID_COMPLETE_STATUS.include?(revision_language.selected_bid.status)
          revision_language_is_complete = true
        end
      else
        revision_language_is_complete = true if released == 0
      end
      unless revision_language_is_complete
        res = true
        break
      end
    end
    res
  end

  # return all the versions for a specified user only
  def user_versions(user)
    if user[:type] == 'Client'
      versions
    else
      translator_ids = [user.id, project.client_id]
      versions.select('DISTINCT zipped_files.*').where('by_user_id IN (?)', translator_ids).order('chgtime')
    end
  end

  def count_track
    self.update_counter = update_counter + 1

    tracks = RevisionTrack.where(resource_id: id)
    update_track(tracks)

    update_track_by_user([project.client_id])
  end

  def track_hierarchy(user_session, recursive = true)
    track = RevisionTrack.new(resource_id: id)
    # seperated to two questions to make sure the add_track gets executed
    if add_track(track, user_session)
      project.track_hierarchy(user_session, recursive) if recursive && project
    end
  end

  def track_with_siblings(user_session, recursive = true)
    track = RevisionTrack.new(resource_id: id)
    add_track(track, user_session)
    if recursive
      chats.each { |chat| chat.track_with_siblings(user_session, recursive) }
    end
  end

  # return list of siblings
  def siblings
    chats + versions
  end

  # -- this is an old and unused function. Don't rely on it --
  def can_delete_me
    released == 0
  end

  def can_delete?
    (released == 0) && chats.empty? && (kind != TA_PROJECT)
  end

  def chat_with_translator(translator)
    chats.where(translator_id: translator.id).first
  end

  def status_text
    if has_open_work
      'Has open work'
    elsif released == 1
      'Released to translators'
    else
      'Not released to translators'
    end
  end

  def update_support_files(support_files)
    support_files.each do |sf|
      revision_support_file = RevisionSupportFile.new(support_file_id: sf[0])
      revision_support_files << revision_support_file
    end
  end

  def get_last_client_version
    last_version = project.client_id.present? ? versions.where(by_user_id: project.client_id).order('id DESC').first : nil
    last_version = versions.first unless last_version
    last_version
  end

  def get_stats
    last_version = get_last_client_version
    last_version ? last_version.get_stats : nil
  end

  def get_human_stats
    last_version = get_last_client_version
    last_version ? last_version.get_human_stats : nil
  end

  def lang_word_count(to_language)
    # For Website Translation Projects, use the word count of the cms_target_language
    ctl_word_count = cms_request&.cms_target_language&.word_count
    return ctl_word_count if ctl_word_count.present? && ctl_word_count > 0

    last_version = get_last_client_version
    return 0 unless last_version

    res = 0

    # CsmRequest is also a TA_PROJECT (0)
    if kind == TA_PROJECT

      # check if we have anything at all on that language. if not, use the original language
      filter_language = last_version.statistics.where('(stat_code = ?) AND (language_id=?)', STATISTICS_WORDS, to_language.id).first ? to_language.id : language_id

      pending_stats = last_version.statistics.where('(stat_code = ?) AND (status != ?) AND (language_id=?)', STATISTICS_WORDS, WORDS_STATUS_DONE_CODE, filter_language)

      pending_stats.each do |stat|
        res += stat.count
      end

      support_files_stats = last_version.statistics.where('(stat_code = ?) AND (status != ?)', STATISTICS_SUPPORT_FILES, WORDS_STATUS_DONE_CODE).first
      res += support_files_stats.count * 10 if support_files_stats
    elsif kind == SIS_PROJECT
      _l, lang_stats = last_version.get_sisulizer_stats
      stats = lang_stats[to_language]
      res = (stats[WORDS_STATUS_NEW_CODE] || 0) + (stats[WORDS_STATUS_MODIFIED_CODE] || 0)
    end

    res
  end

  def minimum_bid_amount
    multiplier = pay_per_word? ? 1 : word_count.to_i
    multiplier * client.minimum_bid_amount
  end

  def missing_amount_for_auto_accept_for_all_languages
    revision_languages.includes(:bids).where('NOT EXISTS (SELECT b.id FROM bids b WHERE (b.revision_language_id = revision_languages.id) AND (b.won = 1))').inject(0) do |sum, rev_lang|
      sum + rev_lang.missing_amount_for_auto_accept
    end
  end

  def pay_per_word?
    (kind == TA_PROJECT) || (kind == SIS_PROJECT)
  end

  def cost_for_bid(bid)
    payment = translator_payment(bid)

    # check if review is also required
    if bid.revision_language.managed_work && (bid.revision_language.managed_work.active == MANAGED_WORK_PENDING_PAYMENT)
      review_price_percentage = from_cms? ? REVIEW_PRICE_PERCENTAGE : 0.5
      payment *= 1 + review_price_percentage
    end

    BigDecimal(payment.round(2).to_s)
  end

  def translator_payment(bid)
    if pay_per_word?
      wc = lang_word_count(bid.revision_language.language)
      # When using a private translator, the bid is created with amount = 0, so
      # the payment amount will be zero (as it should be).
      payment = bid.amount * wc
    else
      payment = bid.amount
    end

    BigDecimal(payment.round(2).to_s)
  end

  def reviewer_payment(bid)
    review_percentage = from_cms? ? REVIEW_PRICE_PERCENTAGE : 0.5
    reviewer_payment = translator_payment(bid) * review_percentage
    BigDecimal(reviewer_payment.round(2).to_s)
  end

  def payment_units
    pay_per_word? ? _(' per word ') : ' per language '
  end

  def currency_name_with_units
    currency.name + payment_units
  end

  def translator_can_access?(translator)
    bid_chat = chats.where(translator_id: translator.id).first
    if bid_chat
      return bid_chat.translator_can_access
    else
      return false
    end
  end

  def is_test?
    (cms_request ? cms_request.website.is_test? : (is_test == 1))
  end

  def release(test = 0)
    self.alert_status = 0
    self.released = 1
    self.release_date = Time.now
    self.is_test = test
    self.bidding_close_time = release_date + (DAY_IN_SECONDS * bidding_duration)
    self.notified = 0
    save!
  end

  def release_problems
    warnings = []
    warnings << _('No file uploaded.') if versions.empty? && (not ta?)
    if language.nil?
      warnings << _('Source language for this project was not selected.')
    end
    if description.blank?
      warnings << _('Description for this revision is missing.')
    end
    if !max_bid_currency || !bidding_duration || !project_completion_duration
      warnings << _('Work conditions are not specified.')
    end
    warnings << 'Name for this revision is missing.' if name.blank?
    if revision_languages.empty?
      warnings << _('No translation languages were selected.')
    end
    warnings
  end

  def force_display_on_ta!
    self.force_display_on_ta = true
    save
  end

  def revision_language
    revision_languages.first
  end

  private

  def cleanup_before_destroy
    # If it's a website translation project and the associated project record
    # has just one revision, destroy the project.
    if cms_request_id.present? && project.revisions.length == 1
      # Must use #delete to avoid running callbacks, otherwise when the project
      # is deleted, it will try to delete this revision again after it no longer
      # exists.
      project.delete
    end

    Rails.logger.info("destroying_revision #{id} - call stack:\n#{Logging.format_callstack(self, caller)}")
  end
end
